const express = require('express');
const promClient = require('prom-client');
const app = express();
const PORT = process.env.PORT || 3004;

const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

app.use(express.json());
app.get('/health', (_req, res) => res.json({ status: 'ok', service: 'ai-service' }));
app.get('/ready',  (_req, res) => res.json({ status: 'ready' }));
app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// TODO: Add ai-service routes here

app.listen(PORT, () => console.log('ai-service listening on port ' + PORT));
module.exports = app;
