import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createService } from '../service.js';
import { createApp } from '../app.js';
import { LabError } from '../errors.js';
import { readVaultSecret } from '../solutions/vault.js';

const config = { username: 'app', password: 'private-value', role_id: 'role', secret_id: 'id' };
function setup(extra = {}) {
  let opened = 0, closed = 0;
  const service = createService({ env: { DB_AUTH_MODE: 'required', WORKSHOP_PROFILE: 'solution' }, loadRuntime: async () => config,
    credentialReader: async () => ({ username: 'app', password: 'private-value' }),
    connectDB: async () => { opened++; return { probe: async () => {}, items: async limit => [{ id: 1, idx: 1, title: String(limit) }], close: async () => { closed++; } }; }, ...extra });
  return { service, counts: () => [opened, closed] };
}
test('strict failures never fall back to valid environment credentials', async () => {
  for (const error of [new LabError('vault_denied', 403), new LabError('vault_unavailable')]) {
    const s = setup({ credentialReader: async () => { throw error; } });
    const result = await s.service(32);
    assert.equal(result.health.unlocked, false); assert.equal(result.status, error.status);
    assert.equal(result.items, undefined); assert.deepEqual(s.counts(), [0, 0]);
    assert.ok(!JSON.stringify(result).includes(config.password));
  }
});
test('baseline is connected but never Vault unlocked', async () => {
  const s = setup({ env: { DB_AUTH_MODE: 'baseline' }, credentialReader: () => { throw Error('must not call'); } });
  const r = await s.service(32); assert.equal(r.status, 200); assert.equal(r.health.channel, 'env'); assert.equal(r.health.unlocked, false);
});
test('concurrent requests coalesce Vault reads and close all independent DB connections', async () => {
  let reads = 0;
  const s = setup({ credentialReader: async () => { reads++; await new Promise(resolve => setTimeout(resolve, 5)); return config; } }); const results = await Promise.all(Array.from({ length: 12 }, () => s.service(32)));
  assert.ok(results.every(r => r.health.unlocked)); assert.deepEqual(s.counts(), [12, 12]); assert.equal(reads, 1);
  await s.service(); assert.equal(reads, 2); // A completed read never authorizes a later request.
});
test('failed probe is not ready and still closes connection', async () => {
  let closed = false;
  const s = setup({ connectDB: async () => ({ probe: async () => { throw Error('secret internal message'); }, close: async () => { closed = true; } }) });
  const r = await s.service(); assert.equal(r.health.state, 'db_unavailable'); assert.ok(closed);
  assert.ok(!JSON.stringify(r).includes('secret internal'));
});
test('incomplete exercise is rendered as 403 without network', async () => {
  const s = createService({ env: {}, loadRuntime: async () => config, credentialReader: async () => { const e = Error('incomplete'); e.code = 'EXERCISE_INCOMPLETE'; throw e; } });
  const r = await s(); assert.equal(r.status, 403); assert.equal(r.health.state, 'exercise_incomplete');
});
test('Vault reference revokes temporary token even when KV read is denied', async () => {
  const calls = [];
  await assert.rejects(readVaultSecret({ addr: 'http://vault', roleId: 'r', secretId: 's', fetchImpl: async (url) => {
    calls.push(url);
    if (url.endsWith('/login')) return { ok: true, status: 200, json: async () => ({ auth: { client_token: 'private-token' } }) };
    if (url.endsWith('revoke-self')) return { ok: true, status: 204 };
    return { ok: false, status: 403 };
  } }), e => e.state === 'vault_denied');
  assert.ok(calls.at(-1).endsWith('revoke-self'));
});
test('HTTP contract validates limits and redacts errors', async () => {
  const app = createApp({ service: async limit => limit === null || limit === undefined ? { health: { unlocked: false } } : { status: 403, health: { state: 'vault_denied' } } });
  const server = app.listen(0, '127.0.0.1'); await new Promise(resolve => server.once('listening', resolve));
  try {
    const base = `http://127.0.0.1:${server.address().port}`;
    for (const v of ['0', '-1', '1.5', 'abc', '1e2']) assert.equal((await fetch(base + '/api/items?limit=' + v)).status, 400);
    const res = await fetch(base + '/api/items?limit=32'); assert.equal(res.status, 403); assert.deepEqual(await res.json(), { error: 'vault_denied' });
  } finally { await new Promise(resolve => server.close(resolve)); }
});
