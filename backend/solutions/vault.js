// Facilitator reference; only selected explicitly with PROFILE=solution.
import { LabError } from '../errors.js';

export async function readVaultSecret({ addr, roleId, secretId, path = 'kv/data/workshop/db', fetchImpl = fetch }) {
  if (!addr || !roleId || !secretId) throw new LabError('configuration_error');
  const base = addr.replace(/\/+$/, '');
  let token;
  async function call(endpoint, method = 'GET', body) {
    let response;
    try {
      response = await fetchImpl(`${base}/v1/${endpoint}`, {
        method, headers: { 'Content-Type': 'application/json', ...(token ? { 'X-Vault-Token': token } : {}) },
        ...(body !== undefined ? { body: JSON.stringify(body) } : {}), signal: AbortSignal.timeout(2500),
      });
    } catch { throw new LabError('vault_unavailable'); }
    if ([400, 401, 403, 404].includes(response.status)) throw new LabError('vault_denied', 403);
    if (!response.ok) throw new LabError('vault_unavailable');
    try { return response.status === 204 ? {} : await response.json(); }
    catch { throw new LabError('vault_unavailable'); }
  }
  try {
    const login = await call('auth/approle/login', 'POST', { role_id: roleId, secret_id: secretId });
    token = login?.auth?.client_token;
    if (!token) throw new LabError('vault_denied', 403);
    const result = await call(path);
    const credentials = result?.data?.data;
    if (typeof credentials?.username !== 'string' || typeof credentials?.password !== 'string' || !credentials.username || !credentials.password) {
      throw new LabError('configuration_error');
    }
    return { username: credentials.username, password: credentials.password };
  } finally {
    if (token) { try { await call('auth/token/revoke-self', 'POST', {}); } catch { /* Token also has a bounded TTL. */ } }
  }
}
