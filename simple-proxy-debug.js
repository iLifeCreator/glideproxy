/**
 * Simple Debug Proxy - Минимальная версия для отладки
 * Без кластеризации, с детальным логированием
 */

require('dotenv').config();
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const http = require('http');
const https = require('https');

// Конфигурация
const CONFIG = {
  port: process.env.PORT || 3000,
  targetProtocol: process.env.TARGET_PROTOCOL || 'https',
  targetDomain: process.env.TARGET_DOMAIN,
  proxyDomain: process.env.PROXY_DOMAIN
};

console.log('Starting Simple Debug Proxy...');
console.log(`Target: ${CONFIG.targetProtocol}://${CONFIG.targetDomain}`);
console.log(`Proxy: ${CONFIG.proxyDomain}`);
console.log(`Port: ${CONFIG.port}`);

const app = express();

// Trust proxy
app.set('trust proxy', true);

// Логирование всех запросов
app.use((req, res, next) => {
  const start = Date.now();
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  console.log('Headers:', JSON.stringify(req.headers, null, 2));
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} - ${res.statusCode} (${duration}ms)`);
  });
  
  next();
});

// Health endpoints - ПЕРЕД proxy middleware
app.get('/health', (req, res) => {
  console.log('Health check requested');
  res.json({
    status: 'healthy',
    version: 'debug-simple',
    target: `${CONFIG.targetProtocol}://${CONFIG.targetDomain}`,
    proxy: CONFIG.proxyDomain,
    timestamp: new Date().toISOString()
  });
});

app.get('/health/detailed', (req, res) => {
  console.log('Detailed health check requested');
  res.json({
    status: 'healthy',
    version: 'debug-simple',
    config: CONFIG,
    process: {
      pid: process.pid,
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      node: process.version
    },
    timestamp: new Date().toISOString()
  });
});

// Простые HTTP агенты
const httpAgent = new http.Agent({
  keepAlive: true,
  maxSockets: 100
});

const httpsAgent = new https.Agent({
  keepAlive: true,
  maxSockets: 100,
  rejectUnauthorized: false
});

// Proxy middleware
const proxyOptions = {
  target: `${CONFIG.targetProtocol}://${CONFIG.targetDomain}`,
  changeOrigin: true,
  secure: false,
  ws: true,
  followRedirects: true,
  agent: CONFIG.targetProtocol === 'https' ? httpsAgent : httpAgent,
  
  // Детальное логирование
  logLevel: 'debug',
  
  onProxyReq: (proxyReq, req, res) => {
    console.log(`Proxying: ${req.method} ${req.url} -> ${CONFIG.targetProtocol}://${CONFIG.targetDomain}${req.url}`);
    
    // Установка заголовков
    proxyReq.setHeader('X-Real-IP', req.ip || 'unknown');
    proxyReq.setHeader('X-Forwarded-Host', CONFIG.proxyDomain || req.headers.host);
    proxyReq.setHeader('X-Forwarded-Proto', 'https');
  },
  
  onProxyRes: (proxyRes, req, res) => {
    console.log(`Response: ${req.method} ${req.url} - Status: ${proxyRes.statusCode}`);
    console.log('Response Headers:', JSON.stringify(proxyRes.headers, null, 2));
    
    // Удаление проблемных заголовков
    delete proxyRes.headers['x-frame-options'];
    delete proxyRes.headers['content-security-policy'];
    
    // Добавление CORS
    proxyRes.headers['access-control-allow-origin'] = '*';
    proxyRes.headers['access-control-allow-methods'] = '*';
    proxyRes.headers['access-control-allow-headers'] = '*';
  },
  
  onError: (err, req, res) => {
    console.error(`Proxy Error for ${req.url}:`, err);
    
    if (!res.headersSent) {
      res.status(502).json({
        error: 'Proxy Error',
        message: err.message,
        code: err.code,
        url: req.url,
        target: `${CONFIG.targetProtocol}://${CONFIG.targetDomain}`,
        timestamp: new Date().toISOString()
      });
    }
  }
};

// Применение proxy для всех путей КРОМЕ /health
app.use((req, res, next) => {
  if (req.path.startsWith('/health')) {
    return next();
  }
  return createProxyMiddleware(proxyOptions)(req, res, next);
});

// 404 handler
app.use((req, res) => {
  console.log(`404 Not Found: ${req.url}`);
  res.status(404).json({
    error: 'Not Found',
    path: req.path,
    timestamp: new Date().toISOString()
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Express Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message,
    timestamp: new Date().toISOString()
  });
});

// Start server
const server = app.listen(CONFIG.port, '0.0.0.0', () => {
  console.log('===============================================');
  console.log('Simple Debug Proxy Started');
  console.log(`Port: ${CONFIG.port}`);
  console.log(`Target: ${CONFIG.targetProtocol}://${CONFIG.targetDomain}`);
  console.log(`Proxy: ${CONFIG.proxyDomain}`);
  console.log('===============================================');
  console.log('Health endpoints:');
  console.log(`  http://localhost:${CONFIG.port}/health`);
  console.log(`  http://localhost:${CONFIG.port}/health/detailed`);
  console.log('===============================================');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});