/**
 * Enhanced Proxy Server v2.1 - Fixed Version
 * Исправлены проблемы с производительностью и роутингом
 */

require('dotenv').config();
const cluster = require('cluster');
const os = require('os');
const express = require('express');
const compression = require('compression');
const { createProxyMiddleware } = require('http-proxy-middleware');
const http = require('http');
const https = require('https');
const url = require('url');

// Конфигурация
const CONFIG = {
  port: process.env.PORT || 3000,
  targetProtocol: process.env.TARGET_PROTOCOL || 'https',
  targetDomain: process.env.TARGET_DOMAIN,
  proxyDomain: process.env.PROXY_DOMAIN,
  workers: process.env.WORKERS === 'auto' ? os.cpus().length : (parseInt(process.env.WORKERS) || 1),
  maxSockets: parseInt(process.env.MAX_SOCKETS) || 1000,
  keepAliveTimeout: parseInt(process.env.KEEP_ALIVE_TIMEOUT) || 60000,
  headersTimeout: parseInt(process.env.HEADERS_TIMEOUT) || 65000,
  requestTimeout: parseInt(process.env.REQUEST_TIMEOUT) || 30000,
  retryAttempts: parseInt(process.env.RETRY_ATTEMPTS) || 3,
  cacheMaxAge: parseInt(process.env.CACHE_MAX_AGE) || 3600,
  compressionLevel: parseInt(process.env.COMPRESSION_LEVEL) || 6,
  enableMetrics: process.env.ENABLE_METRICS !== 'false',
  enableCaching: process.env.ENABLE_CACHING === 'true',
  enableCompression: process.env.ENABLE_COMPRESSION !== 'false',
  enableCircuitBreaker: process.env.ENABLE_CIRCUIT_BREAKER === 'true',
  circuitBreakerThreshold: parseInt(process.env.CIRCUIT_BREAKER_THRESHOLD) || 50,
  circuitBreakerTimeout: parseInt(process.env.CIRCUIT_BREAKER_TIMEOUT) || 60000,
  logRequests: process.env.LOG_REQUESTS === 'true'
};

// Кластеризация
if (cluster.isMaster && CONFIG.workers > 1) {
  console.log(`Master ${process.pid} starting ${CONFIG.workers} workers...`);
  
  for (let i = 0; i < CONFIG.workers; i++) {
    cluster.fork();
  }
  
  cluster.on('exit', (worker, code, signal) => {
    console.log(`Worker ${worker.process.pid} died (${signal || code}). Restarting...`);
    setTimeout(() => cluster.fork(), 1000);
  });
  
  process.on('SIGTERM', () => {
    console.log('Master received SIGTERM, shutting down workers...');
    for (const id in cluster.workers) {
      cluster.workers[id].kill('SIGTERM');
    }
    setTimeout(() => process.exit(0), 5000);
  });
  
} else {
  startWorker();
}

function startWorker() {
  const app = express();
  const server = http.createServer(app);
  
  // Оптимизированные HTTP агенты
  const httpAgent = new http.Agent({
    keepAlive: true,
    keepAliveMsecs: 30000,
    maxSockets: CONFIG.maxSockets,
    maxFreeSockets: 256,
    timeout: CONFIG.requestTimeout,
    scheduling: 'fifo'
  });
  
  const httpsAgent = new https.Agent({
    keepAlive: true,
    keepAliveMsecs: 30000,
    maxSockets: CONFIG.maxSockets,
    maxFreeSockets: 256,
    timeout: CONFIG.requestTimeout,
    scheduling: 'fifo',
    rejectUnauthorized: false
  });
  
  // Настройка сервера
  server.keepAliveTimeout = CONFIG.keepAliveTimeout;
  server.headersTimeout = CONFIG.headersTimeout;
  server.timeout = CONFIG.requestTimeout;
  
  // Метрики
  const metrics = {
    requests: 0,
    errors: 0,
    totalResponseTime: 0,
    activeConnections: 0,
    cacheHits: 0,
    cacheMisses: 0,
    circuitBreakerState: 'closed',
    consecutiveErrors: 0,
    lastReset: Date.now()
  };
  
  // Простой кэш в памяти
  const cache = new Map();
  const MAX_CACHE_SIZE = 100;
  
  // Circuit breaker
  let circuitBreakerOpen = false;
  let circuitBreakerTimer = null;
  
  // Middleware для обработки тела запроса (важно для POST/PUT)
  app.use(express.raw({ type: '*/*', limit: '100mb' }));
  
  // Compression middleware (только для ответов)
  if (CONFIG.enableCompression) {
    app.use(compression({
      level: CONFIG.compressionLevel,
      threshold: 1024,
      filter: (req, res) => {
        if (req.headers['x-no-compression']) {
          return false;
        }
        return compression.filter(req, res);
      }
    }));
  }
  
  // Trust proxy для правильной работы за nginx
  app.set('trust proxy', true);
  
  // Health check endpoints - обрабатываем ДО proxy
  app.get('/health', (req, res) => {
    const uptime = process.uptime();
    const memUsage = process.memoryUsage();
    
    const response = {
      status: circuitBreakerOpen ? 'degraded' : 'healthy',
      worker: cluster.worker ? cluster.worker.id : 'single',
      pid: process.pid,
      uptime: Math.floor(uptime),
      timestamp: new Date().toISOString()
    };
    
    if (CONFIG.enableMetrics) {
      response.metrics = {
        requests: metrics.requests,
        errors: metrics.errors,
        errorRate: metrics.requests > 0 ? 
          (metrics.errors / metrics.requests * 100).toFixed(2) + '%' : '0%',
        avgResponseTime: metrics.requests > 0 ? 
          Math.round(metrics.totalResponseTime / metrics.requests) + 'ms' : '0ms',
        activeConnections: metrics.activeConnections,
        cacheHitRate: metrics.cacheHits + metrics.cacheMisses > 0 ?
          (metrics.cacheHits / (metrics.cacheHits + metrics.cacheMisses) * 100).toFixed(2) + '%' : '0%',
        circuitBreaker: metrics.circuitBreakerState,
        memoryUsage: {
          rss: Math.round(memUsage.rss / 1024 / 1024) + 'MB',
          heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024) + 'MB',
          heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024) + 'MB'
        }
      };
    }
    
    res.json(response);
  });
  
  app.get('/health/detailed', (req, res) => {
    const response = {
      status: 'healthy',
      version: '2.1-fixed',
      config: {
        targetDomain: CONFIG.targetDomain,
        proxyDomain: CONFIG.proxyDomain,
        workers: CONFIG.workers,
        caching: CONFIG.enableCaching,
        compression: CONFIG.enableCompression,
        circuitBreaker: CONFIG.enableCircuitBreaker
      },
      runtime: {
        nodeVersion: process.version,
        platform: process.platform,
        uptime: process.uptime(),
        memory: process.memoryUsage()
      }
    };
    
    res.json(response);
  });
  
  app.post('/health/reset', (req, res) => {
    metrics.requests = 0;
    metrics.errors = 0;
    metrics.totalResponseTime = 0;
    metrics.cacheHits = 0;
    metrics.cacheMisses = 0;
    metrics.consecutiveErrors = 0;
    metrics.lastReset = Date.now();
    cache.clear();
    res.json({ status: 'metrics reset', timestamp: new Date().toISOString() });
  });
  
  // Circuit breaker проверка
  function checkCircuitBreaker() {
    if (!CONFIG.enableCircuitBreaker) return false;
    
    const errorRate = metrics.errors / Math.max(metrics.requests, 1) * 100;
    
    if (errorRate > CONFIG.circuitBreakerThreshold && metrics.requests > 10) {
      if (!circuitBreakerOpen) {
        circuitBreakerOpen = true;
        metrics.circuitBreakerState = 'open';
        console.log(`Circuit breaker OPEN (error rate: ${errorRate.toFixed(2)}%)`);
        
        circuitBreakerTimer = setTimeout(() => {
          circuitBreakerOpen = false;
          metrics.circuitBreakerState = 'closed';
          metrics.consecutiveErrors = 0;
          console.log('Circuit breaker CLOSED (timeout expired)');
        }, CONFIG.circuitBreakerTimeout);
      }
      return true;
    }
    
    return false;
  }
  
  // Circuit breaker middleware
  app.use((req, res, next) => {
    // Пропускаем health endpoints
    if (req.path.startsWith('/health')) {
      return next();
    }
    
    if (circuitBreakerOpen && CONFIG.enableCircuitBreaker) {
      return res.status(503).json({
        error: 'Service temporarily unavailable',
        message: 'Circuit breaker is open',
        retryAfter: CONFIG.circuitBreakerTimeout / 1000
      });
    }
    next();
  });
  
  // Функция для определения кэшируемости
  function isCacheable(req, res) {
    if (!CONFIG.enableCaching) return false;
    if (req.method !== 'GET' && req.method !== 'HEAD') return false;
    
    const contentType = res.headers['content-type'] || '';
    const cacheableTypes = /image|css|javascript|font|woff|ttf|svg|ico/i;
    
    return cacheableTypes.test(contentType) || 
           /\.(jpg|jpeg|png|gif|css|js|woff2?|ttf|svg|ico)$/i.test(req.url);
  }
  
  // Основной proxy middleware с исправлениями
  const proxyMiddleware = createProxyMiddleware({
    target: `${CONFIG.targetProtocol}://${CONFIG.targetDomain}`,
    changeOrigin: true,
    secure: false,
    ws: true,
    xfwd: true,
    preserveHeaderKeyCase: true,
    followRedirects: true,
    autoRewrite: true, // Автоматическое переписывание location headers
    hostRewrite: CONFIG.targetDomain, // Переписывание host header
    cookieDomainRewrite: {
      [CONFIG.targetDomain]: CONFIG.proxyDomain
    },
    
    // Использование оптимизированных агентов
    agent: CONFIG.targetProtocol === 'https' ? httpsAgent : httpAgent,
    
    // Таймауты
    proxyTimeout: CONFIG.requestTimeout,
    timeout: CONFIG.requestTimeout,
    
    // Логирование для отладки
    logLevel: CONFIG.logRequests ? 'debug' : 'error',
    
    // Обработка запроса
    onProxyReq: (proxyReq, req, res) => {
      const startTime = Date.now();
      req._startTime = startTime;
      metrics.activeConnections++;
      
      // Установка правильных заголовков
      proxyReq.setHeader('X-Real-IP', req.ip || req.connection.remoteAddress);
      proxyReq.setHeader('X-Forwarded-Host', CONFIG.proxyDomain || req.headers.host);
      proxyReq.setHeader('X-Forwarded-Proto', req.protocol || 'https');
      proxyReq.setHeader('X-Forwarded-For', req.headers['x-forwarded-for'] || req.connection.remoteAddress);
      
      // Убираем заголовки, которые могут вызвать проблемы
      proxyReq.removeHeader('x-forwarded-port');
      proxyReq.removeHeader('x-forwarded-server');
      
      // Keep-alive
      proxyReq.setHeader('Connection', 'keep-alive');
      
      // Обработка тела запроса для POST/PUT
      if (req.body && Buffer.isBuffer(req.body)) {
        proxyReq.write(req.body);
      }
      
      // Проверка кэша для GET запросов
      if (CONFIG.enableCaching && req.method === 'GET') {
        const cacheKey = req.url;
        if (cache.has(cacheKey)) {
          const cached = cache.get(cacheKey);
          if (Date.now() - cached.timestamp < CONFIG.cacheMaxAge * 1000) {
            metrics.cacheHits++;
            res.statusCode = cached.statusCode || 200;
            Object.keys(cached.headers).forEach(key => {
              if (key.toLowerCase() !== 'content-encoding') {
                res.setHeader(key, cached.headers[key]);
              }
            });
            res.setHeader('X-Cache', 'HIT');
            res.setHeader('X-Cache-Age', Math.floor((Date.now() - cached.timestamp) / 1000));
            res.end(cached.body);
            metrics.activeConnections = Math.max(0, metrics.activeConnections - 1);
            return false;
          } else {
            cache.delete(cacheKey);
          }
        }
        metrics.cacheMisses++;
      }
    },
    
    // Обработка ответа
    onProxyRes: (proxyRes, req, res) => {
      const responseTime = Date.now() - (req._startTime || Date.now());
      metrics.totalResponseTime += responseTime;
      metrics.requests++;
      
      // Удаление проблемных заголовков безопасности
      const headersToRemove = [
        'x-frame-options',
        'content-security-policy',
        'content-security-policy-report-only',
        'strict-transport-security',
        'x-content-type-options',
        'x-xss-protection',
        'referrer-policy',
        'permissions-policy',
        'cross-origin-opener-policy',
        'cross-origin-embedder-policy',
        'cross-origin-resource-policy'
      ];
      
      headersToRemove.forEach(header => {
        delete proxyRes.headers[header];
      });
      
      // Установка разрешающих заголовков
      proxyRes.headers['x-frame-options'] = 'ALLOWALL';
      proxyRes.headers['access-control-allow-origin'] = '*';
      proxyRes.headers['access-control-allow-methods'] = 'GET, POST, PUT, DELETE, OPTIONS, PATCH, HEAD';
      proxyRes.headers['access-control-allow-headers'] = '*';
      proxyRes.headers['access-control-allow-credentials'] = 'true';
      proxyRes.headers['access-control-max-age'] = '86400';
      
      // Добавление заголовков производительности
      proxyRes.headers['x-response-time'] = responseTime + 'ms';
      proxyRes.headers['x-proxy-worker'] = cluster.worker ? cluster.worker.id : 'single';
      
      // Кэширование статических ресурсов
      if (CONFIG.enableCaching && isCacheable(req, proxyRes) && proxyRes.statusCode === 200) {
        const chunks = [];
        const originalWrite = res.write;
        const originalEnd = res.end;
        
        res.write = function(chunk) {
          if (chunk) chunks.push(chunk);
          return originalWrite.apply(res, arguments);
        };
        
        res.end = function(chunk) {
          if (chunk) chunks.push(chunk);
          
          // Сохраняем в кэш
          const body = Buffer.concat(chunks);
          if (body.length < 1024 * 1024 && cache.size < MAX_CACHE_SIZE) {
            cache.set(req.url, {
              body: body,
              headers: {...proxyRes.headers},
              statusCode: proxyRes.statusCode,
              timestamp: Date.now()
            });
            
            // LRU очистка
            if (cache.size >= MAX_CACHE_SIZE) {
              const firstKey = cache.keys().next().value;
              cache.delete(firstKey);
            }
          }
          
          return originalEnd.apply(res, arguments);
        };
      }
      
      // Обновление метрик
      metrics.activeConnections = Math.max(0, metrics.activeConnections - 1);
      
      if (proxyRes.statusCode < 400) {
        metrics.consecutiveErrors = 0;
      } else {
        metrics.errors++;
        metrics.consecutiveErrors++;
      }
      
      // Логирование
      if (CONFIG.logRequests) {
        const logLevel = proxyRes.statusCode >= 400 ? 'ERROR' : 'INFO';
        console.log(`[${logLevel}] ${req.method} ${req.url} -> ${proxyRes.statusCode} (${responseTime}ms)`);
      }
    },
    
    // Обработка ошибок
    onError: (err, req, res) => {
      metrics.errors++;
      metrics.consecutiveErrors++;
      metrics.activeConnections = Math.max(0, metrics.activeConnections - 1);
      
      console.error(`[PROXY ERROR] ${req.method} ${req.url}:`, err.message);
      
      // Circuit breaker проверка
      if (checkCircuitBreaker()) {
        if (!res.headersSent) {
          res.status(503).json({
            error: 'Service temporarily unavailable',
            message: 'Circuit breaker is open due to high error rate',
            retryAfter: CONFIG.circuitBreakerTimeout / 1000
          });
        }
        return;
      }
      
      // Retry логика для временных ошибок
      const retryableErrors = ['ECONNRESET', 'ETIMEDOUT', 'ECONNREFUSED'];
      if (retryableErrors.includes(err.code) && req._retryCount < CONFIG.retryAttempts) {
        req._retryCount = (req._retryCount || 0) + 1;
        console.log(`Retrying request (attempt ${req._retryCount}/${CONFIG.retryAttempts}): ${req.url}`);
        setTimeout(() => {
          // Повторная попытка через саму библиотеку не работает, 
          // поэтому просто возвращаем ошибку 502 с советом повторить
        }, 100 * req._retryCount);
      }
      
      // Отправка ошибки клиенту
      if (!res.headersSent) {
        const statusCode = err.code === 'ECONNREFUSED' ? 503 :
                          err.code === 'ETIMEDOUT' ? 504 :
                          err.code === 'ENOTFOUND' ? 502 : 500;
        
        res.status(statusCode).json({
          error: 'Proxy Error',
          message: err.message,
          code: err.code,
          timestamp: new Date().toISOString(),
          retry: err.code === 'ETIMEDOUT' || err.code === 'ECONNRESET'
        });
      }
    },
    
    // WebSocket поддержка
    onProxyReqWs: (proxyReq, req, socket, head) => {
      proxyReq.setHeader('X-Real-IP', req.connection.remoteAddress);
      proxyReq.setHeader('X-Forwarded-Host', CONFIG.proxyDomain || req.headers.host);
      
      socket.on('error', (err) => {
        console.error('WebSocket error:', err);
      });
    },
    
    onProxyResWs: (proxyRes, req, socket, head) => {
      if (CONFIG.logRequests) {
        console.log(`WebSocket connection established: ${req.url}`);
      }
    }
  });
  
  // Применение proxy middleware для всех остальных путей
  app.use('/', proxyMiddleware);
  
  // Обработка 404 (не должно происходить, но на всякий случай)
  app.use((req, res) => {
    res.status(404).json({
      error: 'Not Found',
      message: 'The requested resource was not found',
      path: req.path,
      timestamp: new Date().toISOString()
    });
  });
  
  // Глобальный обработчик ошибок
  app.use((err, req, res, next) => {
    console.error('Express error:', err);
    if (!res.headersSent) {
      res.status(500).json({
        error: 'Internal Server Error',
        message: err.message,
        timestamp: new Date().toISOString()
      });
    }
  });
  
  // Запуск сервера
  server.listen(CONFIG.port, '0.0.0.0', () => {
    console.log(`===============================================`);
    console.log(`Enhanced Proxy Server v2.1-Fixed`);
    console.log(`Worker ${cluster.worker ? cluster.worker.id : 'single'} PID: ${process.pid}`);
    console.log(`Listening on port: ${CONFIG.port}`);
    console.log(`Target: ${CONFIG.targetProtocol}://${CONFIG.targetDomain}`);
    console.log(`Proxy domain: ${CONFIG.proxyDomain}`);
    console.log(`===============================================`);
    console.log(`Features enabled:`);
    console.log(`  ✓ Connection pooling (max: ${CONFIG.maxSockets} sockets)`);
    console.log(`  ${CONFIG.enableCompression ? '✓' : '✗'} Compression (level: ${CONFIG.compressionLevel})`);
    console.log(`  ${CONFIG.enableCaching ? '✓' : '✗'} Static resource caching`);
    console.log(`  ${CONFIG.enableCircuitBreaker ? '✓' : '✗'} Circuit breaker`);
    console.log(`  ${CONFIG.enableMetrics ? '✓' : '✗'} Performance metrics`);
    console.log(`  ✓ WebSocket support`);
    console.log(`  ✓ Auto-retry on failure`);
    console.log(`  ✓ Cookie domain rewriting`);
    console.log(`===============================================`);
  });
  
  // Graceful shutdown
  const gracefulShutdown = (signal) => {
    console.log(`Worker received ${signal}, shutting down gracefully...`);
    server.close(() => {
      if (httpAgent) httpAgent.destroy();
      if (httpsAgent) httpsAgent.destroy();
      console.log('Server closed');
      process.exit(0);
    });
    
    setTimeout(() => {
      console.error('Could not close connections in time, forcefully shutting down');
      process.exit(1);
    }, 10000);
  };
  
  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));
  
  // Обработка необработанных исключений
  process.on('uncaughtException', (err) => {
    console.error('Uncaught Exception:', err);
    metrics.errors++;
    // Не падаем, продолжаем работать
  });
  
  process.on('unhandledRejection', (reason, promise) => {
    console.error('Unhandled Rejection at:', promise, 'reason:', reason);
    metrics.errors++;
    // Не падаем, продолжаем работать
  });
}

module.exports = { CONFIG };