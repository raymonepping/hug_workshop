// connectors/postgres.js
import pkg from 'pg';
const { Client } = pkg;

export async function connectPostgres({ host, port, database, username, password }) {
  const client = new Client({
    host,
    port: Number(port) || 5432,
    database,
    user: username,
    password,
  });
  await client.connect();
  return client;
}

export async function listItemsPostgres(client, limit = 100) {
  const lim = Number.isInteger(limit) && limit > 0 ? limit : 100;
  // Seed uses table `messages`
  const res = await client.query(
    'SELECT id, idx, title FROM messages ORDER BY id LIMIT $1;',
    [lim]
  );
  return res.rows;
}
