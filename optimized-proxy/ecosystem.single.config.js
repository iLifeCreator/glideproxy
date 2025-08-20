/**
 * PM2 Single Instance Configuration для сервера 2 ядра / 4ГБ ОЗУ
 * Оптимизированная конфигурация для максимальной эффективности памяти
 * Рекомендуется для стабильной работы без перегрузки ресурсов
 */

module.exports = {
  apps: [{
    name: 'enhanced-proxy-single',
    script: './src/enhanced-simple-proxy-final.js',
    
    // Единственный инстанс для экономии памяти
    instances: 1,
    exec_mode: 'fork',
    
    // Автоматический перезапуск
    autorestart: true,
    watch: false,
    
    // Ограичения памяти (консервативно для 4ГБ ОЗУ)
    max_memory_restart: '2000M', // Перезапуск при 2ГБ (50% от общей памяти)
    
    // Production переменные окружения - оптимизированы для single instance
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000,
      TARGET_DOMAIN: 'app.vkusdoterra.ru',
      PROXY_DOMAIN: 'rus.vkusdoterra.ru',
      TARGET_PROTOCOL: 'https',
      
      // Оптимизированные настройки для одного процесса
      WORKERS: 1,
      LOG_LEVEL: 'info',
      ENABLE_METRICS: 'true',
      UV_THREADPOOL_SIZE: 8, // Используем все доступные потоки
      
      // Кэширование - более агрессивное для единственного процесса
      CACHE_MAX_SIZE: 1000,  // Увеличиваем кэш т.к. только один процесс
      STATIC_CACHE_AGE: 86400,
      CACHE_MAX_AGE: 7200,
      
      // Сетевые настройки - оптимизированы для 2-ядерного сервера
      MAX_SOCKETS: 500,      // Умеренное количество сокетов
      MAX_FREE_SOCKETS: 50,
      REQUEST_TIMEOUT: 15000,
      
      // Дополнительные оптимизации
      LOG_REQUESTS: 'false'  // Отключаем детальное логирование для экономии ресурсов
    },
    
    // Логирование
    log_file: './logs/enhanced-single.log',
    out_file: './logs/enhanced-single-out.log',
    error_file: './logs/enhanced-single-error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    merge_logs: true,
    
    // Расширенные настройки для production
    listen_timeout: 3000,
    kill_timeout: 5000,
    
    // Node.js оптимизации - консервативное использование памяти
    node_args: [
      '--max-old-space-size=1800', // 1.8ГБ максимум для Node.js
      '--optimize-for-size'        // Оптимизация для экономии памяти
    ],
    
    // Мониторинг
    monitoring: false,
    
    // Graceful reload
    wait_ready: true,
    
    // Restart настройки - более агрессивные для стабильности
    restart_delay: 1000,
    exp_backoff_restart_delay: 100,
    max_restarts: 5,
    min_uptime: '60s', // Минимальное время работы перед перезапуском
    
    // Отключаем cron restart для стабильности
    // cron_restart: '0 3 * * *'
  }]
};