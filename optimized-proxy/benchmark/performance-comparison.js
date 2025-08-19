/**
 * Performance Comparison Benchmark
 * Сравнивает производительность оптимизированного прокси с оригинальным
 */

const http = require('http');
const https = require('https');
const { performance } = require('perf_hooks');

const URLS = {
  original: 'https://rus.vkusdoterra.ru',
  optimized: 'http://localhost:3000', 
  target: 'https://app.vkusdoterra.ru'
};

const TEST_CONFIG = {
  concurrent: parseInt(process.env.CONCURRENT) || 10,
  requests: parseInt(process.env.REQUESTS) || 100,
  timeout: parseInt(process.env.TIMEOUT) || 30000,
  warmup: parseInt(process.env.WARMUP) || 5
};

class PerformanceBenchmark {
  constructor() {
    this.results = {
      original: { times: [], errors: [] },
      optimized: { times: [], errors: [] },
      target: { times: [], errors: [] }
    };
  }
  
  log(message, data = {}) {
    console.log(JSON.stringify({
      timestamp: new Date().toISOString(),
      message,
      ...data
    }));
  }
  
  async makeRequest(url, timeout = TEST_CONFIG.timeout) {
    return new Promise((resolve, reject) => {
      const startTime = performance.now();
      const protocol = url.startsWith('https') ? https : http;
      
      const req = protocol.get(url, {
        timeout: timeout,
        headers: {
          'User-Agent': 'PerformanceBenchmark/1.0',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Accept-Encoding': 'gzip, deflate, br',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1'
        }
      }, (res) => {
        let data = '';
        let bytes = 0;
        
        res.on('data', chunk => {
          data += chunk;
          bytes += chunk.length;
        });
        
        res.on('end', () => {
          const responseTime = performance.now() - startTime;
          resolve({
            statusCode: res.statusCode,
            responseTime: Math.round(responseTime),
            bytes: bytes,
            contentLength: parseInt(res.headers['content-length'] || '0'),
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
  
  async warmupServer(url, name) {
    this.log(`Warming up ${name}...`);
    
    for (let i = 0; i < TEST_CONFIG.warmup; i++) {
      try {
        await this.makeRequest(url, 10000);
        await new Promise(resolve => setTimeout(resolve, 100));
      } catch (error) {
        // Ignore warmup errors
      }
    }
    
    this.log(`${name} warmed up`);
  }
  
  async runConcurrentTest(url, name, requests) {
    const startTime = performance.now();
    const promises = [];
    
    for (let i = 0; i < requests; i++) {
      promises.push(
        this.makeRequest(url)
          .then(result => {
            this.results[name].times.push(result.responseTime);
            return result;
          })
          .catch(error => {
            this.results[name].errors.push(error);
            return error;
          })
      );
      
      // Stagger requests slightly to avoid thundering herd
      if (i % TEST_CONFIG.concurrent === 0 && i > 0) {
        await Promise.all(promises.slice(i - TEST_CONFIG.concurrent, i));
        await new Promise(resolve => setTimeout(resolve, 50));
      }
    }
    
    await Promise.all(promises);
    const totalTime = performance.now() - startTime;
    
    return {
      totalTime: Math.round(totalTime),
      requestsPerSecond: Math.round(requests / (totalTime / 1000))
    };
  }
  
  calculateStats(times) {
    if (times.length === 0) return null;
    
    const sorted = times.slice().sort((a, b) => a - b);
    const sum = times.reduce((a, b) => a + b, 0);
    
    return {
      min: Math.round(sorted[0]),
      max: Math.round(sorted[sorted.length - 1]),
      mean: Math.round(sum / times.length),
      median: Math.round(sorted[Math.floor(sorted.length / 2)]),
      p95: Math.round(sorted[Math.floor(sorted.length * 0.95)]),
      p99: Math.round(sorted[Math.floor(sorted.length * 0.99)]),
      count: times.length
    };
  }
  
  async runBenchmark() {
    this.log('Starting performance benchmark', TEST_CONFIG);
    
    // Warmup phase
    if (URLS.optimized && TEST_CONFIG.warmup > 0) {
      await this.warmupServer(URLS.optimized, 'optimized');
    }
    
    if (URLS.original && TEST_CONFIG.warmup > 0) {
      try {
        await this.warmupServer(URLS.original, 'original');
      } catch (error) {
        this.log('Original server warmup failed', { error: error.message });
      }
    }
    
    if (URLS.target && TEST_CONFIG.warmup > 0) {
      try {
        await this.warmupServer(URLS.target, 'target');
      } catch (error) {
        this.log('Target server warmup failed', { error: error.message });
      }
    }
    
    this.log('Starting benchmark tests...');
    
    // Test optimized proxy
    if (URLS.optimized) {
      this.log('Testing optimized proxy...');
      const optimizedResults = await this.runConcurrentTest(URLS.optimized, 'optimized', TEST_CONFIG.requests);
      this.log('Optimized proxy test completed', optimizedResults);
    }
    
    // Test original proxy
    if (URLS.original) {
      try {
        this.log('Testing original proxy...');
        const originalResults = await this.runConcurrentTest(URLS.original, 'original', TEST_CONFIG.requests);
        this.log('Original proxy test completed', originalResults);
      } catch (error) {
        this.log('Original proxy test failed', { error: error.message });
      }
    }
    
    // Test target directly
    if (URLS.target) {
      try {
        this.log('Testing target directly...');
        const targetResults = await this.runConcurrentTest(URLS.target, 'target', TEST_CONFIG.requests);
        this.log('Target test completed', targetResults);
      } catch (error) {
        this.log('Target test failed', { error: error.message });
      }
    }
    
    // Calculate and display results
    this.displayResults();
  }
  
  displayResults() {
    this.log('\n=== PERFORMANCE BENCHMARK RESULTS ===\n');
    
    const results = {};
    
    Object.keys(this.results).forEach(name => {
      const data = this.results[name];
      const stats = this.calculateStats(data.times);
      const errorRate = data.errors.length / (data.times.length + data.errors.length) * 100;
      
      results[name] = {
        stats,
        errorRate: Math.round(errorRate * 100) / 100,
        errors: data.errors.length,
        total: data.times.length + data.errors.length
      };
      
      if (stats) {
        this.log(`${name.toUpperCase()} SERVER:`, {
          requests: stats.count,
          errors: data.errors.length,
          errorRate: `${results[name].errorRate}%`,
          responseTime: {
            min: `${stats.min}ms`,
            mean: `${stats.mean}ms`,
            median: `${stats.median}ms`,
            p95: `${stats.p95}ms`,
            p99: `${stats.p99}ms`,
            max: `${stats.max}ms`
          }
        });
      }
    });
    
    // Performance comparison
    if (results.optimized && results.original) {
      const improvement = results.original.stats.mean - results.optimized.stats.mean;
      const improvementPercent = (improvement / results.original.stats.mean) * 100;
      
      this.log('\nPERFORMANCE COMPARISON:', {
        improvement: `${Math.round(improvement)}ms faster`,
        improvementPercent: `${Math.round(improvementPercent * 100) / 100}% improvement`,
        optimizedMean: `${results.optimized.stats.mean}ms`,
        originalMean: `${results.original.stats.mean}ms`
      });
    }
    
    if (results.optimized && results.target) {
      const overhead = results.optimized.stats.mean - results.target.stats.mean;
      const overheadPercent = (overhead / results.target.stats.mean) * 100;
      
      this.log('\nPROXY OVERHEAD:', {
        overhead: `${Math.round(overhead)}ms`,
        overheadPercent: `${Math.round(overheadPercent * 100) / 100}%`,
        proxyMean: `${results.optimized.stats.mean}ms`,
        targetMean: `${results.target.stats.mean}ms`
      });
    }
    
    // Recommendations
    if (results.optimized) {
      const recommendations = [];
      
      if (results.optimized.errorRate > 5) {
        recommendations.push('High error rate detected - check server logs');
      }
      
      if (results.optimized.stats.p95 > 2000) {
        recommendations.push('High P95 latency - consider increasing resources or optimizing further');
      }
      
      if (results.optimized && results.target && 
          (results.optimized.stats.mean - results.target.stats.mean) > 500) {
        recommendations.push('High proxy overhead - review proxy configuration');
      }
      
      if (recommendations.length > 0) {
        this.log('\nRECOMMENDATIONS:', { recommendations });
      }
    }
    
    this.log('\n=== BENCHMARK COMPLETED ===\n');
  }
}

// Run benchmark if called directly
if (require.main === module) {
  const benchmark = new PerformanceBenchmark();
  
  benchmark.runBenchmark().catch(error => {
    console.error('Benchmark failed:', error);
    process.exit(1);
  });
}

module.exports = PerformanceBenchmark;