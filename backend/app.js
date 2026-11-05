import express from 'express';
import cors from 'cors';
import { createService } from './service.js';

export function createApp({ service = createService() } = {}) {
  const app = express(); app.disable('x-powered-by'); app.use(cors());
  app.get('/ping', (_req, res) => res.type('text').send('pong'));
  app.get('/health', async (_req, res) => {
    const result = await service(); res.set('Cache-Control', 'no-store').json(result.health);
  });
  app.get('/api/items', async (req, res) => {
    const raw = req.query.limit;
    if (raw !== undefined && (typeof raw !== 'string' || !/^\d+$/.test(raw) || !Number.isSafeInteger(Number(raw)) || Number(raw) < 1)) {
      return res.status(400).json({ error: 'invalid_limit' });
    }
    const result = await service(raw === undefined ? 32 : Math.min(Number(raw), 100));
    res.set('Cache-Control', 'no-store');
    if (result.status !== 200) return res.status(result.status).json({ error: result.health.state });
    res.json({ items: result.items });
  });
  return app;
}
