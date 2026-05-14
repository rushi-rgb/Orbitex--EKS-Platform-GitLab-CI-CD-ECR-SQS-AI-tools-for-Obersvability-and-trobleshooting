/**
 * API Router — Single Entry Point (Node.js + Nginx)
 * Routes requests to downstream microservices
 */

const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const promClient = require('prom-client');

const app = express();
const PORT = process.env.PORT || 3000;

// ── Prometheus metrics ────────────────────────────────────────────────────────
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register],
});

// ── Middleware ────────────────────────────────────────────────────────────────
app.use(express.json({ limit: '10mb' }));

app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.path, status_code: res.statusCode });
  });
  next();
});

// ── Health & readiness ────────────────────────────────────────────────────────
app.get('/health', (_req, res) => res.json({ status: 'ok' }));
app.get('/ready',  (_req, res) => res.json({ status: 'ready' }));
app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// ── Service routing ───────────────────────────────────────────────────────────
const proxyOptions = (target) => ({
  target,
  changeOrigin: true,
  timeout: 30000,
  on: {
    error: (err, _req, res) => {
      console.error(`Proxy error to ${target}:`, err.message);
      res.status(502).json({ error: 'Service unavailable', service: target });
    },
  },
});

// Content routes
app.use('/api/articles',   createProxyMiddleware(proxyOptions(process.env.CONTENT_SERVICE_URL)));
app.use('/api/companies',  createProxyMiddleware(proxyOptions(process.env.CONTENT_SERVICE_URL)));
app.use('/api/sectors',    createProxyMiddleware(proxyOptions(process.env.CONTENT_SERVICE_URL)));
app.use('/api/analytics',  createProxyMiddleware(proxyOptions(process.env.CONTENT_SERVICE_URL)));

// Auth routes
app.use('/api/auth',       createProxyMiddleware(proxyOptions(process.env.AUTH_SERVICE_URL)));
app.use('/api/sessions',   createProxyMiddleware(proxyOptions(process.env.AUTH_SERVICE_URL)));

// Core routes
app.use('/api/search',     createProxyMiddleware(proxyOptions(process.env.CORE_SERVICE_URL)));
app.use('/api/users',      createProxyMiddleware(proxyOptions(process.env.CORE_SERVICE_URL)));

// AI routes
app.use('/api/ai',         createProxyMiddleware(proxyOptions(process.env.AI_SERVICE_URL)));

// ── Start server ──────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`API Router listening on port ${PORT}`);
});

module.exports = app;
