const express = require('express');
const path = require('path');
function createApp(env = process.env) {
  const app = express(); app.disable('x-powered-by');
  app.get('/config.json', (_req, res) => res.set('Cache-Control', 'no-store').json({ apiBase: env.FRONTEND_API_BASE || 'http://127.0.0.1:13004', itemsLimit: 32 }));
  app.use(express.static(path.join(__dirname, 'public'), { dotfiles: 'deny', etag: false, maxAge: 0 }));
  app.use((_req, res) => res.status(404).type('text').send('Not found'));
  return app;
}
module.exports = { createApp };
if (require.main === module) {
  const port = Number(process.env.PORT || 5173);
  const server = createApp().listen(port, () => console.log(`Workshop viewer listening on ${port}`));
  for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => server.close(() => process.exit(0)));
}
