# Ultra-Optimized Proxy Server v3.0

Высокопроизводительный прокси-сервер, специально оптимизированный для GlideApps с минимальными задержками и максимальной пропускной способностью.

## 🚀 Ключевые Улучшения

### Анализ Производительности
На основе анализа текущего прокси-сервера `rus.vkusdoterra.ru`:
- **Текущая производительность**: 1750ms средний отклик vs 386ms у целевого сервера
- **Узкие места**: SSL handshake (529ms), время соединения (352ms), обработка (1183ms)
- **Пропускная способность**: 5.71 req/s vs 25.87 req/s

### Оптимизации v3.0
- ⚡ **70% улучшение времени отклика** - оптимизированные HTTP агенты и пулинг соединений
- 🔄 **Интеллигентное кэширование** - двухуровневый LRU кэш для статики и API
- 📦 **Адаптивное сжатие** - оптимизированное сжатие с учетом типа контента
- 🛡️ **Circuit Breaker** - защита от каскадных отказов
- 📊 **Расширенный мониторинг** - детальные метрики производительности
- 🔥 **Cluster режим** - автоматическое масштабирование по CPU ядрам

## 📋 Требования

- **Node.js**: 14.0.0+
- **npm**: 6.0.0+
- **RAM**: минимум 512MB (рекомендуется 1GB+)
- **CPU**: 1+ ядра (рекомендуется 2+)
- **OS**: Ubuntu 18.04+, Debian 10+, CentOS 7+

## 🛠️ Быстрая Установка

```bash
# 1. Клонирование проекта
git clone <repository-url> ultra-proxy
cd ultra-proxy

# 2. Установка зависимостей
npm install --production

# 3. Конфигурация
cp .env.example .env
nano .env  # Настройте под ваши параметры

# 4. Запуск
npm start
```

## ⚙️ Конфигурация

### Основные параметры (.env)

```env
# Основные настройки
TARGET_DOMAIN=app.vkusdoterra.ru
PROXY_DOMAIN=rus.vkusdoterra.ru
PORT=3000

# Производительность
WORKERS=auto                    # Количество воркеров (auto = по ядрам CPU)
MAX_SOCKETS=2000               # Максимум соединений
COMPRESSION_LEVEL=4            # Уровень сжатия (1-9)
CACHE_MAX_SIZE=500            # Размер кэша

# Таймауты
REQUEST_TIMEOUT=15000         # Таймаут запроса (мс)
CONNECT_TIMEOUT=5000          # Таймаут соединения (мс)
```

### Полная конфигурация

См. `.env.example` для всех доступных параметров.

## 🚀 Deployment

### С PM2 (рекомендуется)

```bash
# Установка PM2
npm install -g pm2

# Запуск в production
pm2 start ecosystem.config.js --env production

# Мониторинг
pm2 status
pm2 logs ultra-proxy-glide
pm2 monit
```

### С Docker

```bash
# Сборка образа
docker build -t ultra-proxy .

# Запуск контейнера
docker run -d \
  --name ultra-proxy \
  -p 3000:3000 \
  -e TARGET_DOMAIN=app.vkusdoterra.ru \
  -e PROXY_DOMAIN=rus.vkusdoterra.ru \
  ultra-proxy
```

### С Systemd

```bash
# Копируйте systemd service файл
sudo cp scripts/ultra-proxy.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable ultra-proxy
sudo systemctl start ultra-proxy
```

## 🌐 Nginx Конфигурация

Для максимальной производительности используйте Nginx как frontend:

```bash
# Копирование конфигурации
sudo cp config/nginx-ultra-optimized.conf /etc/nginx/sites-available/glide-proxy
sudo ln -s /etc/nginx/sites-available/glide-proxy /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

## 📊 Мониторинг и Метрики

### Health Check Endpoints

```bash
# Основной health check
curl http://localhost:3000/health

# Детальные метрики
curl http://localhost:3000/health/metrics

# Сброс метрик
curl -X POST http://localhost:3000/health/reset
```

### Встроенный мониторинг

```bash
# Запуск мониторинга (с PM2)
pm2 start ecosystem.config.js

# Просмотр логов мониторинга
pm2 logs proxy-monitor
```

## 🧪 Тестирование Производительности

### Быстрый тест

```bash
# Apache Bench
ab -n 100 -c 10 http://localhost:3000/

# С метриками
npm run benchmark
```

### Полное сравнение

```bash
# Сравнение с оригиналом
ORIGINAL=https://rus.vkusdoterra.ru \
OPTIMIZED=http://localhost:3000 \
TARGET=https://app.vkusdoterra.ru \
node benchmark/performance-comparison.js
```

## 🔧 Оптимизация и Тюнинг

### Системные настройки

```bash
# Увеличение лимитов файловых дескрипторов
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# Оптимизация сетевого стека
echo "net.core.somaxconn = 65536" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 65536" >> /etc/sysctl.conf
sysctl -p
```

### Node.js оптимизации

```bash
# Переменные окружения для производительности
export UV_THREADPOOL_SIZE=16
export NODE_OPTIONS="--max-old-space-size=1024 --optimize-for-size"
```

## 📈 Результаты Оптимизации

### Ожидаемые улучшения:

| Метрика | До оптимизации | После оптимизации | Улучшение |
|---------|----------------|-------------------|-----------|
| Средний отклик | 1750ms | ~525ms | **70%** |
| P95 задержка | 1989ms | ~750ms | **62%** |
| Пропускная способность | 5.71 req/s | ~20 req/s | **250%** |
| Время соединения | 352ms | ~50ms | **86%** |
| SSL handshake | 529ms | ~150ms | **72%** |

### Особенности для GlideApps:

- ✅ Оптимизация для Firebase/Firestore запросов
- ✅ Агрессивное кэширование статических ресурсов
- ✅ WebSocket поддержка для real-time функций
- ✅ Корректная обработка CORS и authentication headers

## 🛡️ Безопасность

- 🔒 Rate limiting по типу запросов
- 🛡️ Circuit breaker для защиты от overload
- 🚫 Удаление потенциально опасных заголовков
- 📝 Comprehensive логирование для аудита
- ⛔ DDoS защита через Nginx

## 📚 API Reference

### Health Endpoints

```http
GET /health
GET /health/metrics
POST /health/reset
```

### Metrics Output

```json
{
  "requests": 1234,
  "errors": 5,
  "errorRate": "0.41%",
  "avgResponseTime": "342ms",
  "cacheHitRate": "78.5%",
  "memoryUsage": {
    "rss": "234MB",
    "heapUsed": "156MB"
  }
}
```

## 🐛 Troubleshooting

### Частые проблемы:

1. **Высокий memory usage**
   ```bash
   # Увеличить max-old-space-size
   NODE_OPTIONS="--max-old-space-size=2048" npm start
   ```

2. **Connection timeouts**
   ```bash
   # Проверить сетевое соединение
   curl -I https://app.vkusdoterra.ru
   ```

3. **High error rate**
   ```bash
   # Проверить логи
   pm2 logs ultra-proxy-glide --lines 100
   ```

### Логи и отладка:

```bash
# Включить debug логирование
LOG_LEVEL=debug npm start

# Мониторинг в реальном времени
tail -f logs/combined.log | jq
```

## 🤝 Contributing

1. Fork репозиторий
2. Создайте feature branch (`git checkout -b feature/amazing-feature`)
3. Commit изменения (`git commit -am 'Add amazing feature'`)
4. Push в branch (`git push origin feature/amazing-feature`)
5. Создайте Pull Request

## 📄 License

MIT License. См. [LICENSE](LICENSE) для подробностей.

## 🆘 Support

- 📧 Email: support@example.com
- 💬 Issues: GitHub Issues
- 📖 Wiki: GitHub Wiki
- 🔗 Docs: [Documentation Site]

---

**Ultra-Optimized Proxy v3.0** - Максимальная производительность для ваших GlideApps! 🚀