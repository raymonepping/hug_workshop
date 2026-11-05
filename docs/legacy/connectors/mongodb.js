import { MongoClient } from 'mongodb';

export async function connectMongo({ host, port, database, username, password }) {
  const uri = `mongodb://${encodeURIComponent(username)}:${encodeURIComponent(password)}@${host}:${port}/${database}?authSource=admin`;
  const client = new MongoClient(uri);
  await client.connect();
  return client.db(database);
}

export async function listItemsMongo(db) {
  return db.collection('items').find({}).limit(100).toArray();
}
