/**
 * PM2 Production Configuration для сервера 2 ядра / 4ГБ ОЗУ
 * Оптимизированная конфигурация для максимальной производительности и стабильности
 */

module.exports = {
  apps: [{
    name: 'glide-proxy-enhanced',
    script: './src/enhanced-simple-proxy.js',
    
    // Инстансы и кластеризация (оптимизировано для 2 ядер)
    instances: 2, // По одному инстансу на ядро
    exec_mode: 'fork', // Fork mode для стабильности
    
    // Автоматический перезапуск
    autorestart: true,
    watch: false,
    
    // Ограничения памяти (для 4ГБ ОЗУ)
    max_memory_restart: '1500M', // Перезапуск при 1.5ГБ на процесс
    
    // Production переменные окружения
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000,
      TARGET_DOMAIN: 'app.vkusdoterra.ru',
      PROXY_DOMAIN: 'rus.vkusdoterra.ru',
      TARGET_PROTOCOL: 'https',
      WORKERS: 1, // В fork mode каждый инстанс управляет собой
      LOG_LEVEL: 'info',
      ENABLE_METRICS: 'true',
      UV_THREADPOOL_SIZE: 8,
      // Кэширование оптимизировано для 4ГБ
      CACHE_MAX_SIZE: 800,
      STATIC_CACHE_AGE: 86400,
      MAX_SOCKETS: 1000,
      MAX_FREE_SOCKETS: 100
    },
    
    // Логирование
    log_file: './logs/combined.log',
    out_file: './logs/out.log',
    error_file: './logs/error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    merge_logs: true,
    
    // Расширенные настройки для production
    listen_timeout: 3000,
    kill_timeout: 5000,
    
    // Node.js оптимизации для 4ГБ ОЗУ
    node_args: [
      '--max-old-space-size=2048' // 2ГБ на процесс из 4ГБ общих
    ],
    
    // Мониторинг
    monitoring: false,
    
    // Graceful reload
    wait_ready: true,
    
    // Restart настройки
    restart_delay: 2000,
    exp_backoff_restart_delay: 100,
    max_restarts: 10,
    min_uptime: '30s', // Минимальное время работы перед перезапуском
    
    // Cron restart (опционально - перезапуск каждую ночь в 3:00)
    cron_restart: '0 3 * * *'
  }],

  // Deployment configuration для production
  deploy: {
    production: {
      user: 'root',
      host: ['your-server-ip'],
      ref: 'origin/main',
      repo: 'https://github.com/iLifeCreator/glideproxy.git',
      path: '/opt/glide-proxy',
      'pre-deploy': 'git fetch --all',
      'post-deploy': 'cd optimized-proxy && npm install --production && cp .env.production .env && pm2 reload ecosystem.production.config.js --env production && pm2 save',
      'pre-setup': 'mkdir -p /opt/glide-proxy/optimized-proxy/logs && apt-get update && apt-get install -y nodejs npm'
    }
  }
};