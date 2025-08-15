# 📋 Примеры конфигураций Enhanced Proxy Server v2.0

## 🎯 Готовые конфигурации для разных сценариев

### 1. Минимальная конфигурация (VPS 1 vCPU, 1GB RAM)

```bash
#!/bin/bash
export PROXY_DOMAIN="proxy.yourdomain.com"
export TARGET_DOMAIN="target.com"
export SSL_EMAIL="admin@yourdomain.com"
export PROJECT_NAME="minimal-proxy"
export WORKERS=1
export MAX_MEMORY="256M"
export MAX_SOCKETS=300
export COMPRESSION_LEVEL=6
export ENABLE_CACHING="true"
export ENABLE_CIRCUIT_BREAKER="false"
export RATE_LIMIT=20

sudo ./enhanced-installer-v2.sh
```

### 2. Стандартная конфигурация (VPS 2 vCPU, 2GB RAM)

```bash
#!/bin/bash
export PROXY_DOMAIN="proxy.yourdomain.com"
export TARGET_DOMAIN="target.com"
export SSL_EMAIL="admin@yourdomain.com"
export PROJECT_NAME="standard-proxy"
export WORKERS=2
export MAX_MEMORY="400M"
export MAX_SOCKETS=1000
export COMPRESSION_LEVEL=6
export ENABLE_CACHING="true"
export ENABLE_CIRCUIT_BREAKER="true"
export CIRCUIT_BREAKER_THRESHOLD=50
export RATE_LIMIT=50

sudo ./enhanced-installer-v2.sh
```

### 3. Производительная конфигурация (VPS 4 vCPU, 4GB RAM)

```bash
#!/bin/bash
export PROXY_DOMAIN="proxy.yourdomain.com"
export TARGET_DOMAIN="target.com"
export SSL_EMAIL="admin@yourdomain.com"
export PROJECT_NAME="performance-proxy"
export WORKERS=4
export MAX_MEMORY="800M"
export MAX_SOCKETS=2000
export COMPRESSION_LEVEL=6
export ENABLE_CACHING="true"
export ENABLE_CIRCUIT_BREAKER="true"
export CIRCUIT_BREAKER_THRESHOLD=30
export RATE_LIMIT=100
export KEEP_ALIVE_TIMEOUT=90000

sudo ./enhanced-installer-v2.sh
```

### 4. Максимальная производительность (VPS 8 vCPU, 8GB RAM)

```bash
#!/bin/bash
export PROXY_DOMAIN="proxy.yourdomain.com"
export TARGET_DOMAIN="target.com"
export SSL_EMAIL="admin@yourdomain.com"
export PROJECT_NAME="max-proxy"
export WORKERS=8
export MAX_MEMORY="800M"
export MAX_SOCKETS=5000
export COMPRESSION_LEVEL=3  # Меньше CPU на сжатие
export ENABLE_CACHING="true"
export ENABLE_CIRCUIT_BREAKER="true"
export CIRCUIT_BREAKER_THRESHOLD=20
export RATE_LIMIT=200
export KEEP_ALIVE_TIMEOUT=120000
export REQUEST_TIMEOUT=45000

sudo ./enhanced-installer-v2.sh
```

### 5. Конфигурация для API прокси

```bash
#!/bin/bash
export PROXY_DOMAIN="api-proxy.yourdomain.com"
export TARGET_DOMAIN="api.service.com"
export SSL_EMAIL="admin@yourdomain.com"
export PROJECT_NAME="api-proxy"
export WORKERS=4
export MAX_MEMORY="512M"
export MAX_SOCKETS=3000
export COMPRESSION_LEVEL=0  # Отключить сжатие для API
export ENABLE_CACHING="false"  # API обычно не кэшируется
export ENABLE_CIRCUIT_BREAKER="true"
export CIRCUIT_BREAKER_THRESHOLD=10  # Строже для API
export CIRCUIT_BREAKER_TIMEOUT=30000
export RATE_LIMIT=100
export REQUEST_TIMEOUT=15000  # Быстрый timeout для API

sudo ./enhanced-installer-v2.sh
```

### 6. Конфигурация для статического сайта

```bash
#!/bin/bash
export PROXY_DOMAIN="static-proxy.yourdomain.com"
export TARGET_DOMAIN="static-site.com"
export SSL_EMAIL="admin@yourdomain.com"
export PROJECT_NAME="static-proxy"
export WORKERS=2
export MAX_MEMORY="256M"
export MAX_SOCKETS=1000
export COMPRESSION_LEVEL=9  # Максимальное сжатие для статики
export ENABLE_CACHING="true"
export CACHE_MAX_AGE=86400  # Кэш на 24 часа
export ENABLE_CIRCUIT_BREAKER="false"
export RATE_LIMIT=200

sudo ./enhanced-installer-v2.sh
```

### 7. Конфигурация для WebSocket приложения

```bash
#!/bin/bash
export PROXY_DOMAIN="ws-proxy.yourdomain.com"
export TARGET_DOMAIN="websocket-app.com"
export SSL_EMAIL="admin@yourdomain.com"
export PROJECT_NAME="websocket-proxy"
export WORKERS=4
export MAX_MEMORY="512M"
export MAX_SOCKETS=5000  # Много соединений для WebSocket
export COMPRESSION_LEVEL=0  # WebSocket обычно имеет свое сжатие
export ENABLE_CACHING="false"
export ENABLE_CIRCUIT_BREAKER="true"
export RATE_LIMIT=50
export KEEP_ALIVE_TIMEOUT=300000  # Долгий timeout для WebSocket

sudo ./enhanced-installer-v2.sh
```

### 8. Конфигурация для медиа-контента

```bash
#!/bin/bash
export PROXY_DOMAIN="media-proxy.yourdomain.com"
export TARGET_DOMAIN="media-server.com"
export SSL_EMAIL="admin@yourdomain.com"
export PROJECT_NAME="media-proxy"
export WORKERS=4
export MAX_MEMORY="1G"
export MAX_SOCKETS=2000
export COMPRESSION_LEVEL=0  # Медиа уже сжато
export ENABLE_CACHING="true"
export CACHE_MAX_AGE=3600
export ENABLE_CIRCUIT_BREAKER="true"
export RATE_LIMIT=30  # Ограничить для экономии трафика
export REQUEST_TIMEOUT=60000  # Больше время для больших файлов

sudo ./enhanced-installer-v2.sh
```

## 🔧 Кастомизация после установки

### Изменение конфигурации

```bash
# Перейдите в директорию проекта
cd /opt/your-project-name

# Отредактируйте .env файл
nano .env

# Перезапустите приложение
pm2 restart all
```

### Примеры изменений в .env

#### Увеличение производительности:
```env
WORKERS=8
MAX_SOCKETS=5000
COMPRESSION_LEVEL=3
```

#### Усиление безопасности:
```env
RATE_LIMIT=10
CIRCUIT_BREAKER_THRESHOLD=20
ENABLE_METRICS=false
```

#### Оптимизация для мобильных:
```env
COMPRESSION_LEVEL=9
ENABLE_CACHING=true
CACHE_MAX_AGE=7200
```

## 📊 Мониторинг конфигурации

### Проверка текущей конфигурации:

```bash
# Просмотр переменных окружения
cd /opt/your-project-name
cat .env

# Проверка активных workers
pm2 status

# Проверка использования ресурсов
pm2 monit

# Проверка метрик
curl http://localhost:3000/health | jq '.metrics'
```

### Логирование для отладки:

```bash
# Включить детальное логирование
echo "LOG_REQUESTS=true" >> /opt/your-project-name/.env
pm2 restart all

# Просмотр логов
pm2 logs --lines 100
```

## 🚀 Оптимизация под конкретные задачи

### Для e-commerce сайта:
- High availability важнее производительности
- Включите circuit breaker с низким порогом
- Используйте больше workers для надежности
- Агрессивное кэширование статики

### Для корпоративного портала:
- Безопасность приоритет
- Низкий rate limit
- Отключите публичные метрики
- Включите все логи

### Для публичного API:
- Rate limiting критичен
- Circuit breaker обязателен
- Минимальное кэширование
- Быстрые timeouts

### Для стриминга:
- Большие буферы
- Длинные timeouts
- Отключить сжатие
- Много соединений

## 💡 Советы по выбору конфигурации

1. **Начните с минимальной** и увеличивайте по необходимости
2. **Мониторьте метрики** первые 24 часа после запуска
3. **Тестируйте производительность** перед production
4. **Делайте backup** перед изменениями
5. **Документируйте изменения** для команды

---

Выберите подходящую конфигурацию и адаптируйте под ваши нужды! 🎯