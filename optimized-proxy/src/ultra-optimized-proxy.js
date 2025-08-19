/**
 * Ultra-Optimized Proxy Server v3.0
 * Высокопроизводительный прокси-сервер для GlideApps с фокусом на минимальную задержку
 * 
 * Оптимизации на основе анализа производительности:
 * - Прокси-сервер: 1750ms средний отклик vs целевой сервер: 386ms
 * - Узкие места: SSL handshake (529ms), время соединения (352ms), время обработки (1183ms)
 * - Требуется: улучшение пулинга соединений, кэширования, сжатия
 */

require('dotenv').config();
const cluster = require('cluster');
const os = require('os');
const express = require('express');
const compression = require('compression');
const { createProxyMiddleware } = require('http-proxy-middleware');
const http = require('http');
const https = require('https');
const LRU = require('lru-cache');
const pino = require('pino');
const { performance } = require('perf_hooks');

// Высокопроизводительное логирование
const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  transport: process.env.NODE_ENV === 'development' ? {
    target: 'pino-pretty',
    options: { colorize: true }
  } : undefined
});

// Оптимизированная конфигурация
const CONFIG = {
  port: process.env.PORT || 3000,
  targetProtocol: process.env.TARGET_PROTOCOL || 'https',
  targetDomain: process.env.TARGET_DOMAIN || 'app.vkusdoterra.ru',
  proxyDomain: process.env.PROXY_DOMAIN || 'rus.vkusdoterra.ru',
  
  // Производительность
  workers: process.env.WORKERS === 'auto' ? Math.min(os.cpus().length, 4) : (parseInt(process.env.WORKERS) || 2),
  maxSockets: parseInt(process.env.MAX_SOCKETS) || 2000,
  maxFreeSockets: parseInt(process.env.MAX_FREE_SOCKETS) || 512,
  
  // Таймауты (оптимизированы под GlideApps)
  keepAliveTimeout: parseInt(process.env.KEEP_ALIVE_TIMEOUT) || 30000,
  headersTimeout: parseInt(process.env.HEADERS_TIMEOUT) || 35000,
  requestTimeout: parseInt(process.env.REQUEST_TIMEOUT) || 15000,
  connectTimeout: parseInt(process.env.CONNECT_TIMEOUT) || 5000,
  
  // Кэширование
  cacheMaxAge: parseInt(process.env.CACHE_MAX_AGE) || 7200, // 2 часа
  cacheMaxSize: parseInt(process.env.CACHE_MAX_SIZE) || 500,
  staticCacheAge: parseInt(process.env.STATIC_CACHE_AGE) || 86400, // 24 часа
  
  // Сжатие
  compressionLevel: parseInt(process.env.COMPRESSION_LEVEL) || 4, // Баланс скорость/размер
  compressionThreshold: parseInt(process.env.COMPRESSION_THRESHOLD) || 512,
  
  // Мониторинг
  enableMetrics: process.env.ENABLE_METRICS !== 'false',
  enableHealthCheck: process.env.ENABLE_HEALTH_CHECK !== 'false',
  logRequests: process.env.LOG_REQUESTS === 'true',
  
  // Circuit Breaker
  circuitBreakerThreshold: parseFloat(process.env.CIRCUIT_BREAKER_THRESHOLD) || 0.5,
  circuitBreakerTimeout: parseInt(process.env.CIRCUIT_BREAKER_TIMEOUT) || 30000,
  circuitBreakerMinRequests: parseInt(process.env.CIRCUIT_BREAKER_MIN_REQUESTS) || 20,
  
  // Retry
  retryAttempts: parseInt(process.env.RETRY_ATTEMPTS) || 2,
  retryDelay: parseInt(process.env.RETRY_DELAY) || 100,
  
  // Специфичные для GlideApps оптимизации
  glideStaticPaths: ['/static/', '/_next/', '/assets/', '/images/', '/fonts/'],
  glideApiPaths: ['/api/', '/_api/', '/graphql'],
  preconnectDomains: ['firestore.googleapis.com', 'firebasestorage.googleapis.com', 'fonts.googleapis.com']
};

// Кластеризация с балансировкой нагрузки
if (cluster.isMaster && CONFIG.workers > 1) {
  logger.info(`Master ${process.pid} starting ${CONFIG.workers} workers`);
  
  const workers = [];
  for (let i = 0; i < CONFIG.workers; i++) {
    const worker = cluster.fork();
    workers.push(worker);
  }
  
  // Интеллигентный перезапуск воркеров
  cluster.on('exit', (worker, code, signal) => {
    logger.warn(`Worker ${worker.process.pid} died (${signal || code})`);
    
    // Стagger restart для высокой доступности
    setTimeout(() => {
      const newWorker = cluster.fork();
      const index = workers.findIndex(w => w.id === worker.id);
      if (index !== -1) workers[index] = newWorker;
    }, 500);
  });
  
  // Graceful shutdown
  const shutdown = () => {
    logger.info('Master shutting down...');
    workers.forEach(worker => worker.kill('SIGTERM'));
    setTimeout(() => process.exit(0), 10000);
  };
  
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
  
} else {
  startOptimizedWorker();
}

function startOptimizedWorker() {
  const app = express();
  const server = http.createServer(app);
  
  // Высокопроизводительные HTTP агенты с оптимальными настройками
  const httpAgent = new http.Agent({
    keepAlive: true,
    keepAliveMsecs: 10000,
    maxSockets: CONFIG.maxSockets,
    maxFreeSockets: CONFIG.maxFreeSockets,
    timeout: CONFIG.connectTimeout,
    scheduling: 'fifo',
    family: 4 // Force IPv4 для стабильности
  });
  
  const httpsAgent = new https.Agent({
    keepAlive: true,
    keepAliveMsecs: 10000,
    maxSockets: CONFIG.maxSockets,
    maxFreeSockets: CONFIG.maxFreeSockets,
    timeout: CONFIG.connectTimeout,
    scheduling: 'fifo',
    rejectUnauthorized: false,
    family: 4,
    // SSL оптимизации
    secureProtocol: 'TLS_method',
    ciphers: 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256',
    honorCipherOrder: true,
    secureOptions: require('constants').SSL_OP_NO_SSLv2 | require('constants').SSL_OP_NO_SSLv3
  });
  
  // Настройка сервера для максимальной производительности
  server.keepAliveTimeout = CONFIG.keepAliveTimeout;
  server.headersTimeout = CONFIG.headersTimeout;
  server.timeout = CONFIG.requestTimeout;
  server.maxConnections = CONFIG.maxSockets * 2;
  
  // Высокопроизводительный LRU кэш
  const cache = new LRU({
    max: CONFIG.cacheMaxSize,
    maxAge: CONFIG.cacheMaxAge * 1000,
    updateAgeOnGet: true,
    stale: true
  });
  
  // Кэш для статических ресурсов (более долгий)
  const staticCache = new LRU({
    max: CONFIG.cacheMaxSize * 2,
    maxAge: CONFIG.staticCacheAge * 1000,
    updateAgeOnGet: true,
    stale: true
  });
  
  // Расширенная система метрик
  const metrics = {
    requests: 0,
    errors: 0,
    totalResponseTime: 0,
    activeConnections: 0,
    cacheHits: 0,
    cacheMisses: 0,
    staticCacheHits: 0,
    bytesTransferred: 0,
    connectTime: 0,
    processingTime: 0,
    lastReset: Date.now(),
    
    // Circuit breaker
    circuitBreakerState: 'closed',
    consecutiveErrors: 0,
    lastCircuitBreakerReset: Date.now(),
    
    // Per endpoint metrics
    endpoints: new LRU({ max: 100, maxAge: 3600000 }) // 1 hour
  };
  
  let circuitBreakerOpen = false;
  
  // Middleware порядок оптимизирован для производительности
  app.disable('x-powered-by');
  app.set('trust proxy', true);
  
  // Raw body parsing для всех типов контента
  app.use(express.raw({ 
    type: '*/*', 
    limit: '50mb',
    verify: (req, res, buf) => {
      // Сохраняем raw body для проксирования
      req.rawBody = buf;
    }
  }));
  
  // Интеллигентное сжатие
  app.use(compression({
    level: CONFIG.compressionLevel,
    threshold: CONFIG.compressionThreshold,
    memLevel: 8,
    strategy: require('zlib').constants.Z_DEFAULT_STRATEGY,
    filter: (req, res) => {
      // Не сжимать уже сжатые форматы
      const contentType = res.get('content-type') || '';
      if (/image\/(jpeg|png|gif|webp)|video\/|audio\//.test(contentType)) {
        return false;
      }
      // Не сжимать маленькие файлы
      const contentLength = res.get('content-length');
      if (contentLength && parseInt(contentLength) < CONFIG.compressionThreshold) {
        return false;
      }
      return compression.filter(req, res);
    }
  }));
  
  // Circuit breaker middleware
  app.use((req, res, next) => {
    if (req.path.startsWith('/health') || req.path.startsWith('/_health')) {
      return next();
    }
    
    if (circuitBreakerOpen) {
      return res.status(503).json({
        error: 'Service temporarily unavailable',
        message: 'Circuit breaker is open',
        retryAfter: Math.ceil(CONFIG.circuitBreakerTimeout / 1000)
      });
    }
    
    next();
  });
  
  // Health check endpoints
  if (CONFIG.enableHealthCheck) {
    app.get('/health', (req, res) => {
      const uptime = process.uptime();
      const memUsage = process.memoryUsage();
      
      res.json({
        status: circuitBreakerOpen ? 'degraded' : 'healthy',
        version: '3.0-ultra-optimized',
        worker: cluster.worker ? cluster.worker.id : 'single',
        pid: process.pid,
        uptime: Math.floor(uptime),
        timestamp: new Date().toISOString(),
        config: {
          targetDomain: CONFIG.targetDomain,
          proxyDomain: CONFIG.proxyDomain,
          workers: CONFIG.workers
        }
      });
    });
    
    app.get('/health/metrics', (req, res) => {
      if (!CONFIG.enableMetrics) {
        return res.status(404).json({ error: 'Metrics disabled' });
      }
      
      const avgResponseTime = metrics.requests > 0 ? 
        Math.round(metrics.totalResponseTime / metrics.requests) : 0;
      const errorRate = metrics.requests > 0 ? 
        (metrics.errors / metrics.requests * 100).toFixed(2) : '0.00';
      const cacheHitRate = (metrics.cacheHits + metrics.cacheMisses) > 0 ?
        (metrics.cacheHits / (metrics.cacheHits + metrics.cacheMisses) * 100).toFixed(2) : '0.00';
      
      res.json({
        requests: metrics.requests,
        errors: metrics.errors,
        errorRate: errorRate + '%',
        avgResponseTime: avgResponseTime + 'ms',
        activeConnections: metrics.activeConnections,
        cacheHitRate: cacheHitRate + '%',
        staticCacheHits: metrics.staticCacheHits,
        bytesTransferred: Math.round(metrics.bytesTransferred / 1024 / 1024 * 100) / 100 + 'MB',
        circuitBreakerState: metrics.circuitBreakerState,
        memoryUsage: {
          rss: Math.round(memUsage.rss / 1024 / 1024) + 'MB',
          heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024) + 'MB',
          heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024) + 'MB',
          external: Math.round(memUsage.external / 1024 / 1024) + 'MB'
        },
        cacheStats: {
          size: cache.length,
          staticSize: staticCache.length,
          maxSize: CONFIG.cacheMaxSize
        },
        uptime: Math.floor(process.uptime()),
        lastReset: new Date(metrics.lastReset).toISOString()
      });
    });
    
    app.post('/health/reset', (req, res) => {
      Object.assign(metrics, {
        requests: 0,
        errors: 0,
        totalResponseTime: 0,
        cacheHits: 0,
        cacheMisses: 0,
        staticCacheHits: 0,
        bytesTransferred: 0,
        connectTime: 0,
        processingTime: 0,
        consecutiveErrors: 0,
        lastReset: Date.now()
      });
      
      cache.reset();
      staticCache.reset();
      
      res.json({ 
        status: 'metrics reset', 
        timestamp: new Date().toISOString() 
      });
    });
  }
  
  // Функции для определения типа контента
  function isStaticResource(req) {
    const url = req.url.toLowerCase();
    return CONFIG.glideStaticPaths.some(path => url.startsWith(path)) ||
           /\.(css|js|png|jpg|jpeg|gif|ico|svg|woff2?|ttf|otf|eot|webp|mp4|mp3|pdf)(\?|$)/i.test(url);
  }
  
  function isApiRequest(req) {
    return CONFIG.glideApiPaths.some(path => req.url.startsWith(path));
  }
  
  function getCacheKey(req) {
    return `${req.method}:${req.url}`;
  }
  
  // Circuit breaker проверка
  function checkCircuitBreaker() {
    const now = Date.now();
    const timeSinceLastReset = now - metrics.lastCircuitBreakerReset;
    
    if (timeSinceLastReset > CONFIG.circuitBreakerTimeout) {
      metrics.consecutiveErrors = 0;
      metrics.lastCircuitBreakerReset = now;
    }
    
    if (metrics.requests >= CONFIG.circuitBreakerMinRequests) {
      const errorRate = metrics.errors / metrics.requests;
      
      if (errorRate > CONFIG.circuitBreakerThreshold && 
          metrics.consecutiveErrors >= 5) {
        
        if (!circuitBreakerOpen) {
          circuitBreakerOpen = true;
          metrics.circuitBreakerState = 'open';
          logger.warn(`Circuit breaker OPEN (error rate: ${(errorRate * 100).toFixed(2)}%)`);
          
          setTimeout(() => {
            circuitBreakerOpen = false;
            metrics.circuitBreakerState = 'closed';
            metrics.consecutiveErrors = 0;
            metrics.lastCircuitBreakerReset = Date.now();
            logger.info('Circuit breaker CLOSED');
          }, CONFIG.circuitBreakerTimeout);
        }
        return true;
      }
    }
    
    return false;
  }
  
  // Оптимизированный proxy middleware
  const proxyOptions = {
    target: `${CONFIG.targetProtocol}://${CONFIG.targetDomain}`,
    changeOrigin: true,
    secure: false,
    ws: true,
    xfwd: true,
    preserveHeaderKeyCase: true,
    followRedirects: true,
    autoRewrite: true,
    
    // Использование оптимизированных агентов
    agent: CONFIG.targetProtocol === 'https' ? httpsAgent : httpAgent,
    
    // Таймауты
    proxyTimeout: CONFIG.requestTimeout,
    timeout: CONFIG.requestTimeout,
    
    // Буферизация для оптимизации
    buffer: false, // Отключаем для streaming
    
    logLevel: CONFIG.logRequests ? 'debug' : 'error',
    
    onProxyReq: (proxyReq, req, res) => {
      const startTime = performance.now();
      req._startTime = startTime;
      req._cacheKey = getCacheKey(req);
      
      metrics.activeConnections++;
      
      // Проверка кэша ПЕРЕД отправкой запроса
      if (req.method === 'GET' || req.method === 'HEAD') {
        const cacheKey = req._cacheKey;
        let cached = null;
        
        if (isStaticResource(req)) {
          cached = staticCache.get(cacheKey);
          if (cached) {
            metrics.staticCacheHits++;
            metrics.cacheHits++;
            
            // Отправляем кэшированный ответ
            res.statusCode = cached.statusCode || 200;
            Object.keys(cached.headers || {}).forEach(key => {
              res.setHeader(key, cached.headers[key]);
            });
            res.setHeader('X-Cache', 'HIT-STATIC');
            res.setHeader('X-Cache-Age', Math.floor((Date.now() - cached.timestamp) / 1000));
            res.end(cached.body);
            
            metrics.activeConnections--;
            return; // Прерываем proxy запрос
          }
        } else {
          cached = cache.get(cacheKey);
          if (cached) {
            metrics.cacheHits++;
            
            res.statusCode = cached.statusCode || 200;
            Object.keys(cached.headers || {}).forEach(key => {
              res.setHeader(key, cached.headers[key]);
            });
            res.setHeader('X-Cache', 'HIT');
            res.setHeader('X-Cache-Age', Math.floor((Date.now() - cached.timestamp) / 1000));
            res.end(cached.body);
            
            metrics.activeConnections--;
            return;
          }
        }
        
        metrics.cacheMisses++;
      }
      
      // Настройка заголовков для оптимальной производительности
      proxyReq.setHeader('Connection', 'keep-alive');
      proxyReq.setHeader('Keep-Alive', 'timeout=30, max=100');
      
      // Заголовки для GlideApps
      proxyReq.setHeader('X-Real-IP', req.ip || req.connection.remoteAddress);
      proxyReq.setHeader('X-Forwarded-Host', CONFIG.proxyDomain);
      proxyReq.setHeader('X-Forwarded-Proto', 'https');
      proxyReq.setHeader('X-Forwarded-For', req.headers['x-forwarded-for'] || req.connection.remoteAddress);
      
      // Удаляем потенциально проблемные заголовки
      proxyReq.removeHeader('x-forwarded-port');
      proxyReq.removeHeader('x-forwarded-server');
      
      // Оптимизация для API запросов
      if (isApiRequest(req)) {
        proxyReq.setHeader('Accept-Encoding', 'gzip, deflate, br');
        proxyReq.setHeader('Cache-Control', 'no-cache');
      }
      
      // Обработка тела запроса
      if (req.rawBody && req.rawBody.length > 0) {
        proxyReq.write(req.rawBody);
      }
    },
    
    onProxyRes: (proxyRes, req, res) => {
      const responseTime = performance.now() - (req._startTime || performance.now());
      metrics.totalResponseTime += responseTime;
      metrics.requests++;
      metrics.processingTime += responseTime;
      
      // Отслеживание размера трафика
      const contentLength = parseInt(proxyRes.headers['content-length'] || '0');
      metrics.bytesTransferred += contentLength;
      
      // Оптимизация заголовков ответа
      const headersToRemove = [
        'x-frame-options',
        'content-security-policy',
        'content-security-policy-report-only',
        'x-content-type-options',
        'x-xss-protection',
        'referrer-policy'
      ];
      
      headersToRemove.forEach(header => {
        delete proxyRes.headers[header];
      });
      
      // Установка оптимальных заголовков
      proxyRes.headers['x-frame-options'] = 'ALLOWALL';
      proxyRes.headers['access-control-allow-origin'] = '*';
      proxyRes.headers['access-control-allow-methods'] = 'GET,POST,PUT,DELETE,OPTIONS,PATCH,HEAD';
      proxyRes.headers['access-control-allow-headers'] = '*';
      proxyRes.headers['access-control-allow-credentials'] = 'true';
      
      // Заголовки производительности
      proxyRes.headers['x-response-time'] = Math.round(responseTime) + 'ms';
      proxyRes.headers['x-proxy-version'] = '3.0-ultra';
      proxyRes.headers['x-worker-id'] = cluster.worker ? cluster.worker.id : 'single';
      
      // Интеллигентное кэширование
      if (proxyRes.statusCode === 200 && (req.method === 'GET' || req.method === 'HEAD')) {
        const chunks = [];
        let shouldCache = false;
        
        const contentType = proxyRes.headers['content-type'] || '';
        const isStatic = isStaticResource(req);
        
        // Определяем, нужно ли кэшировать
        if (isStatic) {
          shouldCache = true;
          // Устанавливаем долгий кэш для статических ресурсов
          proxyRes.headers['cache-control'] = `public, max-age=${CONFIG.staticCacheAge}, immutable`;
        } else if (!isApiRequest(req) && !contentType.includes('text/html')) {
          shouldCache = true;
          proxyRes.headers['cache-control'] = `public, max-age=${CONFIG.cacheMaxAge}`;
        }
        
        if (shouldCache && contentLength < 1024 * 1024) { // Кэшируем файлы до 1MB
          const originalWrite = res.write;
          const originalEnd = res.end;
          
          res.write = function(chunk) {
            if (chunk) chunks.push(Buffer.from(chunk));
            return originalWrite.apply(res, arguments);
          };
          
          res.end = function(chunk) {
            if (chunk) chunks.push(Buffer.from(chunk));
            
            const body = Buffer.concat(chunks);
            const cacheData = {
              body: body,
              headers: { ...proxyRes.headers },
              statusCode: proxyRes.statusCode,
              timestamp: Date.now()
            };
            
            if (isStatic) {
              staticCache.set(req._cacheKey, cacheData);
            } else {
              cache.set(req._cacheKey, cacheData);
            }
            
            return originalEnd.apply(res, arguments);
          };
        }
      }
      
      // Обновление метрик
      metrics.activeConnections = Math.max(0, metrics.activeConnections - 1);
      
      if (proxyRes.statusCode < 400) {
        metrics.consecutiveErrors = 0;
      } else {
        metrics.errors++;
        metrics.consecutiveErrors++;
        checkCircuitBreaker();
      }
      
      // Логирование производительности
      if (CONFIG.logRequests || responseTime > 1000) {
        const level = proxyRes.statusCode >= 400 ? 'warn' : 'info';
        logger[level]({
          method: req.method,
          url: req.url,
          status: proxyRes.statusCode,
          responseTime: Math.round(responseTime),
          contentLength: contentLength,
          isStatic: isStaticResource(req),
          cached: req._fromCache || false
        }, 'Request processed');
      }
    },
    
    onError: (err, req, res) => {
      metrics.errors++;
      metrics.consecutiveErrors++;
      metrics.activeConnections = Math.max(0, metrics.activeConnections - 1);
      
      const responseTime = performance.now() - (req._startTime || performance.now());
      metrics.totalResponseTime += responseTime;
      
      logger.error({
        error: err.message,
        code: err.code,
        method: req.method,
        url: req.url,
        responseTime: Math.round(responseTime)
      }, 'Proxy error');
      
      checkCircuitBreaker();
      
      if (!res.headersSent) {
        const statusCode = err.code === 'ECONNREFUSED' ? 503 :
                          err.code === 'ETIMEDOUT' ? 504 :
                          err.code === 'ENOTFOUND' ? 502 : 500;
        
        res.status(statusCode).json({
          error: 'Proxy Error',
          message: err.message,
          code: err.code,
          timestamp: new Date().toISOString(),
          canRetry: ['ETIMEDOUT', 'ECONNRESET', 'ECONNREFUSED'].includes(err.code)
        });
      }
    },
    
    // WebSocket оптимизации
    onProxyReqWs: (proxyReq, req, socket, head) => {
      proxyReq.setHeader('X-Real-IP', req.connection.remoteAddress);
      proxyReq.setHeader('X-Forwarded-Host', CONFIG.proxyDomain);
      proxyReq.setHeader('X-Forwarded-Proto', 'wss');
      
      socket.on('error', (err) => {
        logger.error({ error: err.message }, 'WebSocket error');
      });
    }
  };
  
  const proxyMiddleware = createProxyMiddleware(proxyOptions);
  
  // Применяем proxy для всех путей
  app.use('/', proxyMiddleware);
  
  // Global error handler
  app.use((err, req, res, next) => {
    logger.error({ error: err.message, stack: err.stack }, 'Express error');
    if (!res.headersSent) {
      res.status(500).json({
        error: 'Internal Server Error',
        message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong',
        timestamp: new Date().toISOString()
      });
    }
  });
  
  // Запуск сервера
  server.listen(CONFIG.port, '0.0.0.0', () => {
    logger.info({
      version: '3.0-ultra-optimized',
      worker: cluster.worker ? cluster.worker.id : 'single',
      pid: process.pid,
      port: CONFIG.port,
      target: `${CONFIG.targetProtocol}://${CONFIG.targetDomain}`,
      proxy: CONFIG.proxyDomain,
      workers: CONFIG.workers,
      maxSockets: CONFIG.maxSockets,
      cacheSize: CONFIG.cacheMaxSize,
      compressionLevel: CONFIG.compressionLevel
    }, 'Ultra-Optimized Proxy Server started');
  });
  
  // Graceful shutdown
  const gracefulShutdown = (signal) => {
    logger.info(`Worker received ${signal}, shutting down gracefully...`);
    
    server.close(() => {
      if (httpAgent) httpAgent.destroy();
      if (httpsAgent) httpsAgent.destroy();
      logger.info('Server closed gracefully');
      process.exit(0);
    });
    
    setTimeout(() => {
      logger.error('Could not close connections in time, forcefully shutting down');
      process.exit(1);
    }, 10000);
  };
  
  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));
  
  // Error handling
  process.on('uncaughtException', (err) => {
    logger.error({ error: err.message, stack: err.stack }, 'Uncaught Exception');
    metrics.errors++;
  });
  
  process.on('unhandledRejection', (reason, promise) => {
    logger.error({ reason, promise }, 'Unhandled Rejection');
    metrics.errors++;
  });
  
  // Периодическая очистка кэша и сбор статистики
  setInterval(() => {
    const memUsage = process.memoryUsage();
    if (memUsage.heapUsed > 500 * 1024 * 1024) { // 500MB
      cache.prune();
      staticCache.prune();
      if (global.gc) global.gc();
    }
    
    logger.debug({
      cacheSize: cache.length,
      staticCacheSize: staticCache.length,
      memoryUsage: Math.round(memUsage.heapUsed / 1024 / 1024) + 'MB',
      activeConnections: metrics.activeConnections
    }, 'Periodic cleanup');
  }, 60000); // Каждую минуту
}

module.exports = { CONFIG };