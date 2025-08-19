/**
 * PM2 Ecosystem Configuration for Ultra-Optimized Proxy
 * Оптимизировано для максимальной производительности и стабильности
 */

module.exports = {
  apps: [{
    name: 'ultra-proxy-glide',
    script: './src/ultra-optimized-proxy.js',
    
    // Инстансы и кластеризация - используем fork mode, так как приложение управляет кластером внутренне
    instances: 1, // Один инстанс, приложение создает собственные воркеры
    exec_mode: 'fork',
    
    // Автоматический перезапуск
    autorestart: true,
    watch: false,
    
    // Ограничения памяти
    max_memory_restart: '1G',
    
    // Переменные окружения
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      TARGET_DOMAIN: 'app.vkusdoterra.ru',
      PROXY_DOMAIN: 'rus.vkusdoterra.ru',
      TARGET_PROTOCOL: 'https',
      WORKERS: 'auto', // Позволяем приложению управлять воркерами
      LOG_LEVEL: 'info',
      ENABLE_METRICS: 'true',
      UV_THREADPOOL_SIZE: 16
    },
    
    env_development: {
      NODE_ENV: 'development',
      LOG_LEVEL: 'debug',
      LOG_REQUESTS: 'true',
      watch: true,
      ignore_watch: ['node_modules', 'logs']
    },
    
    // Логирование
    log_file: './logs/combined.log',
    out_file: './logs/out.log',
    error_file: './logs/error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    
    // Расширенные настройки
    listen_timeout: 3000,
    kill_timeout: 5000,
    
    // Node.js оптимизации
    node_args: [
      '--max-old-space-size=1024',
      '--optimize-for-size',
      '--gc-interval=100'
    ],
    
    // Мониторинг
    monitoring: false, // Отключаем PM2 Plus если не используется
    
    // Graceful reload
    wait_ready: true,
    
    // Restart delay
    restart_delay: 4000,
    
    // Exponential backoff restart delay
    exp_backoff_restart_delay: 100,
    max_restarts: 10,
    min_uptime: '10s'
  }, {
    // Отдельный процесс для мониторинга (опционально)
    name: 'proxy-monitor',
    script: './scripts/monitor.js',
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    env: {
      NODE_ENV: 'production',
      MONITOR_INTERVAL: 30000, // 30 секунд
      PROXY_URL: 'http://localhost:3000'
    },
    log_file: './logs/monitor.log',
    out_file: './logs/monitor-out.log',
    error_file: './logs/monitor-error.log'
  }],

  // Deployment configuration (опционально)
  deploy: {
    production: {
      user: 'deploy',
      host: ['your-server.com'],
      ref: 'origin/master',
      repo: 'git@github.com:your-repo/ultra-proxy.git',
      path: '/opt/ultra-proxy',
      'pre-deploy': 'git fetch --all',
      'post-deploy': 'npm install --production && pm2 reload ecosystem.config.js --env production && pm2 save',
      'pre-setup': 'mkdir -p /opt/ultra-proxy/logs'
    }
  }
};