import mysql from 'mysql2/promise';

export async function connectMySQL({ host, port, database, username, password }) {
  return mysql.createConnection({
    host, port: Number(port) || 3306, user: username, password, database
  });
}

export async function listItemsMySQL(conn) {
  const [rows] = await conn.execute(
    'SELECT id, idx, title FROM messages ORDER BY id LIMIT 100;'
  );
   return rows;
 }