import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { readVaultSecret as starterReader } from './vault.js';
import { readVaultSecret as solutionReader } from './solutions/vault.js';
import { connectDatabase } from './db.js';
import { LabError, publicError } from './errors.js';

export function createService({ env = process.env, loadRuntime, credentialReader, connectDB = connectDatabase } = {}) {
  const mode = env.DB_AUTH_MODE || 'required';
  const profile = env.WORKSHOP_PROFILE || 'starter';
  const readRuntime = loadRuntime || (async () => JSON.parse(await readFile(path.join(env.RUNTIME_DIR || '/runtime', 'config.json'), 'utf8')));
  const reader = credentialReader || (profile === 'solution' ? solutionReader : starterReader);
  // No shared initialization or authorization cache: each bounded request owns and closes its client.
  return async function execute(limit = null) {
    let db;
    try {
      if (!['required', 'baseline'].includes(mode) || !['starter', 'solution'].includes(profile)) throw new LabError('configuration_error');
      if (env.DB_TLS && !['true', 'false'].includes(env.DB_TLS)) throw new LabError('configuration_error');
      let runtime;
      try { runtime = await readRuntime(); } catch { throw new LabError('configuration_error'); }
      let credentials;
      if (mode === 'baseline') {
        credentials = { username: runtime.username, password: runtime.password };
      } else {
        credentials = await reader({ addr: env.VAULT_ADDR || 'http://vault:8200', roleId: runtime.role_id,
          secretId: runtime.secret_id, path: 'kv/data/workshop/db' });
      }
      if (!credentials?.username || !credentials?.password) throw new LabError('configuration_error');
      try {
        db = await connectDB({ host: env.DB_HOST || 'postgres', database: env.DB_NAME || 'workshop', ...credentials, tls: env.DB_TLS === 'true' });
        await db.probe();
        const items = limit === null ? undefined : await db.items(limit);
        return { status: 200, health: { ok: true, dbReady: true, mode, channel: mode === 'baseline' ? 'env' : 'vault-kv',
          unlocked: mode === 'required', state: mode === 'baseline' ? 'baseline' : 'ready' }, items };
      } catch { throw new LabError('db_unavailable'); }
    } catch (e) {
      const error = publicError(e);
      return { status: error.status, health: { ok: true, dbReady: false, mode, channel: null, unlocked: false, state: error.state } };
    } finally { if (db) { try { await db.close(); } catch { /* Connection already failed. */ } } }
  };
}
