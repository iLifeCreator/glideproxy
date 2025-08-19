/**
 * Enhanced Simple Proxy Server v2.5
 * Based on successful simple-proxy.js with additional optimizations
 * Adds LRU caching, better compression, and enhanced monitoring
 * Maintains stability while improving performance
 */

require('dotenv').config();
const express = require('express');
const compression = require('compression');
const { createProxyMiddleware } = require('http-proxy-middleware');
const http = require('http');
const https = require('https');
const { LRUCache } = require('lru-cache');
const pino = require('pino');
const { performance } = require('perf_hooks');

// Logger configuration
const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  transport: process.env.NODE_ENV === 'development' ? {
    target: 'pino-pretty',
    options: { colorize: true }
  } : undefined
});

// Configuration
const CONFIG = {
  port: process.env.PORT || 3000,
  targetProtocol: process.env.TARGET_PROTOCOL || 'https',
  targetDomain: process.env.TARGET_DOMAIN || 'app.vkusdoterra.ru',
  proxyDomain: process.env.PROXY_DOMAIN || 'rus.vkusdoterra.ru',
  
  // Performance settings
  maxSockets: parseInt(process.env.MAX_SOCKETS) || 100,
  maxFreeSockets: parseInt(process.env.MAX_FREE_SOCKETS) || 10,
  requestTimeout: parseInt(process.env.REQUEST_TIMEOUT) || 15000,
  
  // Caching
  cacheMaxAge: parseInt(process.env.CACHE_MAX_AGE) || 7200, // 2 hours
  cacheMaxSize: parseInt(process.env.CACHE_MAX_SIZE) || 500,
  staticCacheAge: parseInt(process.env.STATIC_CACHE_AGE) || 86400, // 24 hours
  
  // Monitoring
  enableMetrics: process.env.ENABLE_METRICS !== 'false',
  logRequests: process.env.LOG_REQUESTS === 'true'
};

const app = express();

// High-performance HTTP agents (proven to work)
const httpAgent = new http.Agent({
  keepAlive: true,
  keepAliveMsecs: 30000,
  maxSockets: CONFIG.maxSockets,
  maxFreeSockets: CONFIG.maxFreeSockets,
  timeout: CONFIG.requestTimeout
});

const httpsAgent = new https.Agent({
  keepAlive: true,
  keepAliveMsecs: 30000,
  maxSockets: CONFIG.maxSockets,
  maxFreeSockets: CONFIG.maxFreeSockets,
  timeout: CONFIG.requestTimeout,
  rejectUnauthorized: false
});

// LRU Cache for static resources (v10 syntax)
const staticCache = new LRUCache({
  max: CONFIG.cacheMaxSize * 2, // More space for static content
  ttl: CONFIG.staticCacheAge * 1000,
  updateAgeOnGet: true
});

// LRU Cache for dynamic content (v10 syntax)
const dynamicCache = new LRUCache({
  max: CONFIG.cacheMaxSize,
  ttl: CONFIG.cacheMaxAge * 1000,
  updateAgeOnGet: true
});

// Metrics tracking
const metrics = {
  requests: 0,
  errors: 0,
  totalResponseTime: 0,
  cacheHits: 0,
  cacheMisses: 0,
  staticCacheHits: 0,
  dynamicCacheHits: 0,
  bytesTransferred: 0,
  startTime: Date.now()
};

// Middleware setup
app.disable('x-powered-by');
app.set('trust proxy', true);

// Intelligent compression (same as ultra-optimized)
app.use(compression({
  level: 4, // Good balance between compression and speed
  threshold: 512,
  filter: (req, res) => {
    const contentType = res.get('content-type') || '';
    // Don't compress already compressed formats
    if (/image\/(jpeg|png|gif|webp)|video\/|audio\//.test(contentType)) {
      return false;
    }
    return compression.filter(req, res);
  }
}));

// Cache middleware
app.use((req, res, next) => {
  if (req.method !== 'GET') {
    return next();
  }
  
  const cacheKey = req.url;
  const isStatic = /\.(css|js|png|jpg|gif|woff2?|ttf|ico)$/.test(req.url) || 
                  /\/(static|_next|assets|images|fonts)\//.test(req.url);
  
  const cache = isStatic ? staticCache : dynamicCache;
  const cached = cache.get(cacheKey);
  
  if (cached) {
    metrics.cacheHits++;
    if (isStatic) metrics.staticCacheHits++;
    else metrics.dynamicCacheHits++;
    
    // Restore cached headers
    Object.keys(cached.headers).forEach(header => {
      res.set(header, cached.headers[header]);
    });
    
    res.set('X-Proxy-Cache', 'HIT');
    res.set('X-Cache-Type', isStatic ? 'static' : 'dynamic');
    
    return res.status(cached.statusCode).send(cached.body);
  }
  
  metrics.cacheMisses++;
  res.set('X-Proxy-Cache', 'MISS');
  next();
});

// Health check endpoints
if (CONFIG.enableMetrics) {
  app.get('/health', (req, res) => {
    const uptime = process.uptime();
    const memUsage = process.memoryUsage();
    
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: Math.floor(uptime),
      memory: {
        rss: Math.round(memUsage.rss / 1024 / 1024) + 'MB',
        heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024) + 'MB',
        heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024) + 'MB'
      },
      version: require('../package.json').version
    });
  });

  app.get('/health/metrics', (req, res) => {
    const uptime = process.uptime();
    const avgResponseTime = metrics.requests > 0 ? 
      Math.round(metrics.totalResponseTime / metrics.requests) : 0;
    
    const cacheHitRate = (metrics.cacheHits + metrics.cacheMisses) > 0 ? 
      ((metrics.cacheHits / (metrics.cacheHits + metrics.cacheMisses)) * 100).toFixed(2) : 0;
    
    res.json({
      uptime: Math.floor(uptime),
      requests: metrics.requests,
      errors: metrics.errors,
      errorRate: metrics.requests > 0 ? 
        ((metrics.errors / metrics.requests) * 100).toFixed(2) + '%' : '0%',
      avgResponseTime: avgResponseTime + 'ms',
      cacheStats: {
        hits: metrics.cacheHits,
        misses: metrics.cacheMisses,
        hitRate: cacheHitRate + '%',
        staticHits: metrics.staticCacheHits,
        dynamicHits: metrics.dynamicCacheHits,
        staticCacheSize: staticCache.size,
        dynamicCacheSize: dynamicCache.size
      },
      bytesTransferred: Math.round(metrics.bytesTransferred / 1024 / 1024) + 'MB',
      requestsPerSecond: metrics.requests > 0 ? 
        (metrics.requests / uptime).toFixed(2) : 0
    });
  });
}

// Request logging middleware
if (CONFIG.logRequests) {
  app.use((req, res, next) => {
    const start = performance.now();
    
    res.on('finish', () => {
      const duration = performance.now() - start;
      logger.info({
        method: req.method,
        url: req.url,
        status: res.statusCode,
        duration: Math.round(duration) + 'ms',
        userAgent: req.get('User-Agent'),
        ip: req.ip,
        cache: res.get('X-Proxy-Cache')
      });
    });
    
    next();
  });
}

// Main proxy configuration
const proxyOptions = {
  target: `${CONFIG.targetProtocol}://${CONFIG.targetDomain}`,
  changeOrigin: true,
  secure: false,
  followRedirects: true,
  agent: CONFIG.targetProtocol === 'https' ? httpsAgent : httpAgent,
  timeout: CONFIG.requestTimeout,
  
  // Headers modification
  onProxyReq: (proxyReq, req, res) => {
    const startTime = performance.now();
    req.proxyStartTime = startTime;
    
    // Set proper host header for the target
    proxyReq.setHeader('Host', CONFIG.targetDomain);
    
    // Remove problematic headers
    proxyReq.removeHeader('x-forwarded-host');
    proxyReq.removeHeader('x-forwarded-proto');
    
    // Add custom headers for optimization
    proxyReq.setHeader('Accept-Encoding', 'gzip, deflate, br');
    proxyReq.setHeader('Connection', 'keep-alive');
    
    metrics.requests++;
  },
  
  onProxyRes: (proxyRes, req, res) => {
    const endTime = performance.now();
    const duration = endTime - (req.proxyStartTime || endTime);
    metrics.totalResponseTime += duration;
    
    // Track bytes transferred
    const contentLength = proxyRes.headers['content-length'];
    if (contentLength) {
      metrics.bytesTransferred += parseInt(contentLength);
    }
    
    // CORS headers for iframe embedding
    res.setHeader('X-Frame-Options', 'SAMEORIGIN');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
    
    // Performance headers
    res.setHeader('X-Proxy-Server', 'Enhanced-Simple-Proxy-v2.5');
    res.setHeader('X-Response-Time', Math.round(duration) + 'ms');
    
    // Remove server identification headers for security
    delete proxyRes.headers['server'];
    delete proxyRes.headers['x-powered-by'];
    
    // Cache logic for GET requests
    if (req.method === 'GET' && proxyRes.statusCode === 200) {
      const isStatic = /\.(css|js|png|jpg|gif|woff2?|ttf|ico)$/.test(req.url) || 
                      /\/(static|_next|assets|images|fonts)\//.test(req.url);
      
      const cache = isStatic ? staticCache : dynamicCache;
      const cacheKey = req.url;
      
      // Buffer the response for caching
      const chunks = [];
      
      proxyRes.on('data', (chunk) => {
        chunks.push(chunk);
      });
      
      proxyRes.on('end', () => {
        const body = Buffer.concat(chunks);
        
        // Cache the response
        cache.set(cacheKey, {
          statusCode: proxyRes.statusCode,
          headers: { ...proxyRes.headers },
          body: body
        });
      });
    }
  },
  
  onError: (err, req, res) => {
    metrics.errors++;
    logger.error({
      error: err.message,
      url: req.url,
      method: req.method
    }, 'Proxy error');
    
    if (!res.headersSent) {
      res.status(502).json({
        error: 'Proxy Error',
        message: 'Unable to connect to target server',
        timestamp: new Date().toISOString()
      });
    }
  }
};

// Apply proxy middleware
const proxy = createProxyMiddleware(proxyOptions);
app.use('/', proxy);

// Start server
const server = app.listen(CONFIG.port, '0.0.0.0', () => {
  logger.info({
    port: CONFIG.port,
    target: `${CONFIG.targetProtocol}://${CONFIG.targetDomain}`,
    proxy: CONFIG.proxyDomain,
    version: '2.5',
    features: ['LRU Caching', 'Intelligent Compression', 'Performance Monitoring', 'Enhanced Headers'],
    cacheConfig: {
      staticMaxAge: CONFIG.staticCacheAge + 's',
      dynamicMaxAge: CONFIG.cacheMaxAge + 's',
      maxSize: CONFIG.cacheMaxSize
    }
  }, 'Enhanced Simple Proxy Server started successfully');
});

// Graceful shutdown
const shutdown = (signal) => {
  logger.info(`Received ${signal}, shutting down gracefully...`);
  
  server.close(() => {
    logger.info('Server closed');
    
    // Log final metrics
    const uptime = process.uptime();
    const avgResponseTime = metrics.requests > 0 ? 
      Math.round(metrics.totalResponseTime / metrics.requests) : 0;
    
    logger.info({
      finalMetrics: {
        uptime: Math.floor(uptime) + 's',
        totalRequests: metrics.requests,
        totalErrors: metrics.errors,
        avgResponseTime: avgResponseTime + 'ms',
        cacheHits: metrics.cacheHits,
        cacheHitRate: (metrics.cacheHits + metrics.cacheMisses) > 0 ? 
          ((metrics.cacheHits / (metrics.cacheHits + metrics.cacheMisses)) * 100).toFixed(2) + '%' : '0%'
      }
    }, 'Final statistics');
    
    process.exit(0);
  });
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Error handling
process.on('uncaughtException', (error) => {
  logger.error({ error: error.message, stack: error.stack }, 'Uncaught exception');
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error({ reason, promise }, 'Unhandled promise rejection');
});