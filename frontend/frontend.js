require('dotenv').config();
const express = require('express');
const path = require('path');

const app = express();
const PORT = Number(process.env.PORT || process.env.FRONTEND_PORT || 5173);
const publicDir = __dirname;

app.use(express.static(publicDir, {
  index: false,
  cacheControl: false,
  etag: false,
}));

app.get('/config.json', (_req, res) => {
  res.json({
    apiBase: process.env.FRONTEND_API_BASE || 'http://localhost:3004',
    itemsLimit: Number(process.env.ITEMS_LIMIT || process.env.FRONTEND_ITEMS_LIMIT || 32),
  });
});

app.get('/', (_req, res) => {
  res.sendFile(path.join(publicDir, 'index.html'));
});

// Catch-all for deep links (Express v5-safe)
app.use((_req, res) => {
  res.sendFile(path.join(publicDir, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`🔭 Frontend served at http://localhost:${PORT}`);
});