import couchbase from 'couchbase';

export async function connectCouchbase({ host, username, password, bucket = 'workshop' }) {
  const cluster = await couchbase.connect(`couchbase://${host}`, { username, password });
  const b = cluster.bucket(bucket);
  const c = b.defaultCollection();
  return { cluster, bucket: b, collection: c };
}

export async function listItemsCouchbase({ cluster, bucket }) {
  // assumes a primary index exists; your seed script can ensure this
  const q = `SELECT META().id, * FROM \`${bucket.name}\` LIMIT 100;`;
  const res = await cluster.query(q);
  // Normalize shape
  return res.rows.map(r => r[bucket.name]);
}
