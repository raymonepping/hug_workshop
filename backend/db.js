import pg from 'pg';
import { LabError } from './errors.js';

export async function connectDatabase({ host, database, username, password, tls = false }) {
  const client = new pg.Client({ host, port: 5432, database, user: username, password,
    ssl: tls ? { rejectUnauthorized: true } : false,
    connectionTimeoutMillis: 2500, query_timeout: 2500, statement_timeout: 2500 });
  // Idle/asynchronous driver errors must not crash the process or print secrets.
  client.on('error', () => {});
  try { await client.connect(); }
  catch { await client.end().catch(() => {}); throw new LabError('db_unavailable'); }
  return {
    probe: () => client.query('SELECT 1'),
    items: async (limit) => (await client.query('SELECT id, idx, title FROM messages ORDER BY idx, id LIMIT $1', [limit])).rows,
    close: () => client.end(),
  };
}
