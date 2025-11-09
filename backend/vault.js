// vault.js
import axios from 'axios';

/**
 * readVaultSecret:
 *  - Works with KV v2: accepts "kv/workshop" or "kv/data/workshop" (with/without leading /v1)
 *  - Works with dynamic DB creds: "database/creds/<role>"
 * Returns a flat object (e.g., { username, password }) when possible.
 */
export async function readVaultSecret({ addr, token, path }) {
  if (!addr || !token || !path) {
    throw new Error('Vault parameters missing (addr/token/path)');
  }

  const base = addr.replace(/\/$/, '');
  let apiPath = path.replace(/^\/+/, ''); // trim leading /

  // Normalize to /v1/...
  if (!apiPath.startsWith('v1/')) {
    if (apiPath.startsWith('database/creds/')) {
      apiPath = `v1/${apiPath}`;
    } else {
      // KV v2: ensure /v1/<mount>/data/<rest>
      // If already contains /data/, keep it; else insert it.
      const parts = apiPath.split('/');
      const mount = parts[0];                // e.g. "kv"
      const rest  = parts.slice(1).join('/'); // e.g. "workshop"
      if (/\/data\//.test(apiPath) || apiPath.startsWith(`${mount}/data/`)) {
        apiPath = `v1/${apiPath}`;
      } else {
        apiPath = `v1/${mount}/data/${rest}`;
      }
    }
  }

  const url = `${base}/${apiPath}`;
  const res = await axios.get(url, { headers: { 'X-Vault-Token': token } });

  const body = res.data ?? {};
  // Dynamic creds shape: usually { data: { username, password, ... } }
  if (apiPath.includes('/database/creds/')) {
    return body.data || body;
  }

  // KV v2 shape: { data: { data: {...}, metadata: {...} } }
  return body?.data?.data ?? body?.data ?? {};
}

/** Minimal token heuristic */
export function looksLikeVaultToken(t) {
  if (!t) return false;
  if (t.startsWith('<<') || t.toLowerCase() === 'changeme') return false;
  return true;
}
