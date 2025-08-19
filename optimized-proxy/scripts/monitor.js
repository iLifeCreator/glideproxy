/**
 * Monitoring Script for Ultra-Optimized Proxy
 * Отслеживает производительность и здоровье прокси-сервера
 */

const http = require('http');
const https = require('https');
const { performance } = require('perf_hooks');

const CONFIG = {
  proxyUrl: process.env.PROXY_URL || 'http://localhost:3000',
  targetUrl: process.env.TARGET_URL || 'https://app.vkusdoterra.ru',
  interval: parseInt(process.env.MONITOR_INTERVAL) || 30000, // 30 seconds
  alertThreshold: parseInt(process.env.ALERT_THRESHOLD) || 2000, // 2 seconds
  errorThreshold: parseInt(process.env.ERROR_THRESHOLD) || 5, // 5 consecutive errors
  logLevel: process.env.LOG_LEVEL || 'info'
};

class ProxyMonitor {
  constructor() {
    this.consecutiveErrors = 0;
    this.metrics = {
      uptime: 0,
      totalRequests: 0,
      totalErrors: 0,
      avgResponseTime: 0,
      lastCheck: null,
      status: 'unknown'
    };
    
    this.log('info', 'Proxy Monitor started', CONFIG);
    this.start();
  }
  
  log(level, message, data = {}) {
    const timestamp = new Date().toISOString();
    const logData = { timestamp, level, message, ...data };
    console.log(JSON.stringify(logData));
  }
  
  async makeRequest(url, timeout = 10000) {
    return new Promise((resolve, reject) => {
      const startTime = performance.now();
      const protocol = url.startsWith('https') ? https : http;
      
      const req = protocol.get(url, {
        timeout: timeout,
        headers: {
          'User-Agent': 'ProxyMonitor/1.0'
        }
      }, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          const responseTime = performance.now() - startTime;
          resolve({
            statusCode: res.statusCode,
            responseTime: Math.round(responseTime),
            data: data,
            headers: res.headers
          });
        });
      });
      
      req.on('error', (err) => {
        reject({
          error: err.message,
          code: err.code,
          responseTime: performance.now() - startTime
        });
      });
      
      req.on('timeout', () => {
        req.destroy();
        reject({
          error: 'Request timeout',
          code: 'TIMEOUT',
          responseTime: timeout
        });
      });
    });
  }
  
  async checkHealth() {
    try {
      const healthUrl = `${CONFIG.proxyUrl}/health`;
      const result = await this.makeRequest(healthUrl, 5000);
      
      if (result.statusCode === 200) {
        let healthData = {};
        try {
          healthData = JSON.parse(result.data);
        } catch (e) {
          // Health endpoint might return plain text
        }
        
        this.consecutiveErrors = 0;
        this.metrics.status = 'healthy';
        this.metrics.lastCheck = new Date().toISOString();
        
        this.log('debug', 'Health check passed', {
          responseTime: result.responseTime,
          status: result.statusCode,
          health: healthData
        });
        
        return { success: true, ...result, health: healthData };
      } else {
        throw new Error(`Health check failed with status ${result.statusCode}`);
      }
    } catch (error) {
      this.consecutiveErrors++;
      this.metrics.status = 'unhealthy';
      
      this.log('error', 'Health check failed', {
        error: error.error || error.message,
        consecutiveErrors: this.consecutiveErrors
      });
      
      return { success: false, error };
    }
  }
  
  async checkMetrics() {
    try {
      const metricsUrl = `${CONFIG.proxyUrl}/health/metrics`;
      const result = await this.makeRequest(metricsUrl, 5000);
      
      if (result.statusCode === 200) {
        const metricsData = JSON.parse(result.data);
        
        this.log('info', 'Metrics collected', {
          requests: metricsData.requests,
          errors: metricsData.errors,
          errorRate: metricsData.errorRate,
          avgResponseTime: metricsData.avgResponseTime,
          cacheHitRate: metricsData.cacheHitRate,
          memoryUsage: metricsData.memoryUsage,
          activeConnections: metricsData.activeConnections
        });
        
        // Check for performance alerts
        const avgResponseTime = parseInt(metricsData.avgResponseTime) || 0;
        if (avgResponseTime > CONFIG.alertThreshold) {
          this.log('warn', 'High response time detected', {
            avgResponseTime: avgResponseTime,
            threshold: CONFIG.alertThreshold
          });
        }
        
        const errorRate = parseFloat(metricsData.errorRate) || 0;
        if (errorRate > 10) { // 10% error rate
          this.log('warn', 'High error rate detected', {
            errorRate: metricsData.errorRate,
            errors: metricsData.errors,
            requests: metricsData.requests
          });
        }
        
        return metricsData;
      }
    } catch (error) {
      this.log('warn', 'Failed to collect metrics', {
        error: error.error || error.message
      });
    }
    
    return null;
  }
  
  async performanceTest() {
    try {
      const testUrl = CONFIG.proxyUrl;
      const startTime = performance.now();
      
      // Test proxy response
      const proxyResult = await this.makeRequest(testUrl, 15000);
      const proxyTime = proxyResult.responseTime;
      
      // Test direct target response for comparison
      let targetTime = null;
      try {
        const targetResult = await this.makeRequest(CONFIG.targetUrl, 15000);
        targetTime = targetResult.responseTime;
      } catch (e) {
        // Target might not be directly accessible
      }
      
      const performance_data = {
        proxyResponseTime: proxyTime,
        targetResponseTime: targetTime,
        overhead: targetTime ? proxyTime - targetTime : null,
        proxyStatus: proxyResult.statusCode,
        timestamp: new Date().toISOString()
      };
      
      this.log('info', 'Performance test completed', performance_data);
      
      // Alert if overhead is too high
      if (performance_data.overhead && performance_data.overhead > 1000) {
        this.log('warn', 'High proxy overhead detected', {
          overhead: performance_data.overhead,
          proxyTime: proxyTime,
          targetTime: targetTime
        });
      }
      
      return performance_data;
      
    } catch (error) {
      this.log('error', 'Performance test failed', {
        error: error.error || error.message
      });
      return null;
    }
  }
  
  async runMonitoringCycle() {
    this.log('debug', 'Starting monitoring cycle');
    
    const startTime = performance.now();
    
    // Check health
    const healthResult = await this.checkHealth();
    
    if (healthResult.success) {
      // Collect metrics
      const metrics = await this.checkMetrics();
      
      // Performance test (every 3rd cycle to reduce load)
      if (this.metrics.totalRequests % 3 === 0) {
        await this.performanceTest();
      }
      
      this.metrics.totalRequests++;
    } else {
      this.metrics.totalErrors++;
      
      // Alert on consecutive failures
      if (this.consecutiveErrors >= CONFIG.errorThreshold) {
        this.log('error', 'Multiple consecutive health check failures', {
          consecutiveErrors: this.consecutiveErrors,
          threshold: CONFIG.errorThreshold
        });
      }
    }
    
    const cycleTime = performance.now() - startTime;
    this.log('debug', 'Monitoring cycle completed', {
      cycleTime: Math.round(cycleTime),
      consecutiveErrors: this.consecutiveErrors,
      totalRequests: this.metrics.totalRequests,
      totalErrors: this.metrics.totalErrors
    });
  }
  
  start() {
    // Initial health check
    this.runMonitoringCycle();
    
    // Set up interval
    setInterval(() => {
      this.runMonitoringCycle();
    }, CONFIG.interval);
    
    this.log('info', 'Monitoring started', {
      interval: CONFIG.interval,
      proxyUrl: CONFIG.proxyUrl,
      targetUrl: CONFIG.targetUrl
    });
  }
  
  // Graceful shutdown
  stop() {
    this.log('info', 'Monitoring stopped');
    process.exit(0);
  }
}

// Start monitoring
const monitor = new ProxyMonitor();

// Handle graceful shutdown
process.on('SIGTERM', () => monitor.stop());
process.on('SIGINT', () => monitor.stop());

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception in monitor:', err);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection in monitor:', reason);
  process.exit(1);
});