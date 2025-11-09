// server.js
import 'dotenv/config.js';
import express from 'express';
import cors from 'cors';
import { initDB, listItems } from './db.js';

const app = express();
const PORT = process.env.PORT || 3004;

const DEFAULT_ITEMS_LIMIT = Number(process.env.DEFAULT_ITEMS_LIMIT || 100);
const MAX_ITEMS_LIMIT     = Number(process.env.MAX_ITEMS_LIMIT || 500);

// auth gating (matches db.js semantics)
const DB_AUTH_MODE      = String(process.env.DB_AUTH_MODE || 'preferred').toLowerCase();     // required|preferred|env_only
const DB_SECONDARY_MODE = String(process.env.DB_SECONDARY_MODE || 'disabled').toLowerCase(); // disabled|env_fallback

app.use(cors());
app.use(express.json());

let dbHandle = null;

async function ensureDB() {
  if (!dbHandle) {
    try {
      dbHandle = await initDB();
    } catch (err) {
      console.error('[DB init failed]', err.message || err);
      dbHandle = null;
    }
  }
  return !!dbHandle;
}

function isUnlocked() {
  const source = dbHandle?.authSource; // 'vault-kv' | 'vault-dynamic' | 'env'
  if (!source) return false;

  const usedVault = String(source).startsWith('vault');
  if (DB_AUTH_MODE === 'required')       return usedVault;
  if (DB_AUTH_MODE === 'env_only')       return true; // data is never gated if you chose pure env mode
  // preferred:
  if (DB_SECONDARY_MODE === 'disabled')  return usedVault; // only “unlock” if Vault was actually used
  return true; // env_fallback => unlocked either way
}

// Health: includes unlock status
app.get('/health', async (_req, res) => {
  const ready = await ensureDB();
  res.json({
    ok: true,
    dbReady: ready,
    mode: DB_AUTH_MODE,
    channel: dbHandle?.authSource || null,
    unlocked: ready ? isUnlocked() : false,   // 👈 add this
  });
});

// Data endpoint (gated)
app.get('/api/items', async (req, res) => {
  try {
    const ready = await ensureDB();
    if (!ready) return res.status(503).json({ error: 'Database not ready' });

    if (!isUnlocked()) {
      return res.status(403).json({
        error: 'locked',
        message: 'The data remains silent until the keeper is acknowledged.',
      }); // 👈 mythic gate text
    }

    const raw = Number(req.query.limit);
    const limit = Number.isInteger(raw) && raw > 0
      ? Math.min(raw, MAX_ITEMS_LIMIT)
      : DEFAULT_ITEMS_LIMIT;

    const items = await listItems(dbHandle, { limit });
    res.json({ items });
  } catch (err) {
    console.error('[items error]', err);
    res.status(500).json({ error: String(err.message || err) });
  }
});

// Optional: quick ping
app.get('/ping', (_req, res) => res.send('pong'));

app.listen(PORT, async () => {
  console.log(`Backend listening on :${PORT}`);
  await ensureDB();
});
