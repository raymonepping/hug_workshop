// db.js
import 'dotenv/config.js';
import { readVaultSecret } from './vault.js';

import { connectMySQL,    listItemsMySQL }     from './connectors/mysql.js';
import { connectPostgres, listItemsPostgres }  from './connectors/postgres.js';
import { connectMongo,    listItemsMongo }     from './connectors/mongodb.js';
import { connectCouchbase,listItemsCouchbase } from './connectors/couchbase.js';

function normLimit(v, def = 100, max = 500) {
  const n = Number(v);
  if (!Number.isInteger(n) || n <= 0) return def;
  return Math.min(n, max);
}

const {
  // Vault
  VAULT_ADDR,
  VAULT_TOKEN,
  // Accept either; prefer VAULT_DB_SECRET_PATH if set, otherwise fallback to VAULT_DB_KV_PATH
  VAULT_DB_SECRET_PATH: ENV_VAULT_DB_SECRET_PATH,
  VAULT_DB_KV_PATH:     ENV_VAULT_DB_KV_PATH,

  // DB selection & connection
  DB_TYPE,
  DB_HOST,
  DB_PORT,
  DB_NAME,
  DB_USERNAME,
  DB_PASSWORD,
  DB_TLS,

  // Gating
  DB_AUTH_MODE = 'preferred',      // required | preferred | env_only
  DB_SECONDARY_MODE = 'disabled',  // disabled | env_fallback
} = process.env;

const VAULT_DB_SECRET_PATH = ENV_VAULT_DB_SECRET_PATH || ENV_VAULT_DB_KV_PATH;

const ALLOWED = new Set(['mysql', 'postgres', 'mongodb', 'couchbase']);

function defaultPortFor(dbType) {
  switch (dbType) {
    case 'mysql':    return 3306;
    case 'postgres': return 5432;
    case 'mongodb':  return 27017;
    default:         return undefined;
  }
}

function looksLikeRealVaultToken(t) {
  if (!t) return false;
  if (t.startsWith('<<') || t.toLowerCase() === 'changeme') return false;
  return true;
}

function warn(msg) { console.warn(`[db] ${msg}`); }

async function getCredentials() {
  const mode = String(DB_AUTH_MODE).toLowerCase();
  const secondary = String(DB_SECONDARY_MODE).toLowerCase();

  const vaultConfigured =
    !!VAULT_ADDR && !!VAULT_DB_SECRET_PATH && looksLikeRealVaultToken(VAULT_TOKEN);

  if (mode === 'env_only') {
    if (!DB_USERNAME || !DB_PASSWORD) {
      throw new Error('Auth(env_only): DB_USERNAME/DB_PASSWORD missing');
    }
    return { username: DB_USERNAME, password: DB_PASSWORD, authSource: 'env' };
  }

  if (vaultConfigured) {
    try {
      const path = String(VAULT_DB_SECRET_PATH);
      // Detect dynamic creds vs KV
      const normalized = path.replace(/^v1\//, '');
      const isDynamic = normalized.startsWith('database/creds/');

      const secret = await readVaultSecret({
        addr: VAULT_ADDR,
        token: VAULT_TOKEN,
        path, // can be "kv/workshop", "kv/data/workshop", "v1/kv/data/workshop", or "database/creds/<role>"
      });

      // accept both username/user and password/pass
      const username = secret?.username ?? secret?.user;
      const password = secret?.password ?? secret?.pass;

      if (username && password) {
        return { username, password, authSource: isDynamic ? 'vault-dynamic' : 'vault-kv' };
      }
      warn(`Vault secret at ${VAULT_DB_SECRET_PATH} missing username/password`);
      // fall through
    } catch (e) {
      const code = e?.response?.status;
      warn(`Vault read failed (${code ?? 'error'}): ${String(e?.message || e)}`);
      // fall through
    }
  } else {
    warn('Vault not fully configured (addr/token/path).');
  }

  if (mode === 'required') {
    throw new Error('Auth(required): Vault credentials unavailable');
  }

  if (secondary === 'env_fallback') {
    if (DB_USERNAME && DB_PASSWORD) {
      warn('Falling back to env credentials (preferred + env_fallback).');
      return { username: DB_USERNAME, password: DB_PASSWORD, authSource: 'env' };
    }
    throw new Error('Auth(preferred): Vault failed and no env fallback available');
  }

  throw new Error('Auth(preferred): Vault failed and secondary=disabled');
}

export async function initDB() {
  if (!ALLOWED.has(DB_TYPE)) {
    throw new Error(`Unsupported DB_TYPE: ${DB_TYPE}. Use one of: ${[...ALLOWED].join(', ')}`);
  }
  if (!DB_HOST) throw new Error('DB_HOST is required');

  const port     = (DB_PORT && String(DB_PORT).trim() !== '') ? Number(DB_PORT) : defaultPortFor(DB_TYPE);
  const database = DB_NAME || 'workshop';
  const tls      = String(DB_TLS).toLowerCase() === 'true';

  const { username, password, authSource } = await getCredentials();

  switch (DB_TYPE) {
    case 'mysql': {
      const conn = await connectMySQL({ host: DB_HOST, port, database, username, password, tls });
      return { driver: 'mysql', conn, authSource };
    }
    case 'postgres': {
      const client = await connectPostgres({ host: DB_HOST, port, database, username, password, tls });
      return { driver: 'postgres', client, authSource };
    }
    case 'mongodb': {
      const db = await connectMongo({ host: DB_HOST, port, database, username, password, tls });
      return { driver: 'mongodb', db, authSource };
    }
    case 'couchbase': {
      const cb = await connectCouchbase({ host: DB_HOST, username, password, bucket: database, tls });
      return { driver: 'couchbase', cb, authSource };
    }
    default:
      throw new Error(`Unsupported DB_TYPE: ${DB_TYPE}`);
  }
}

export async function listItems(handle, opts = {}) {
  const limit = normLimit(opts.limit, 100, 500);
  switch (handle.driver) {
    case 'mysql':     return listItemsMySQL(handle.conn,       limit);
    case 'postgres':  return listItemsPostgres(handle.client,  limit);
    case 'mongodb':   return listItemsMongo(handle.db,         limit);
    case 'couchbase': return listItemsCouchbase(handle.cb,     limit);
    default: throw new Error('Unknown driver');
  }
}
