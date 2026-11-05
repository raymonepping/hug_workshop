import { createApp } from './app.js';
const port = Number(process.env.PORT || 3004);
const server = createApp().listen(port, () => console.log(`Workshop API listening on ${port}`));
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => server.close(() => process.exit(0)));
