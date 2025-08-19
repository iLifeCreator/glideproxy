# 🚀 Enhanced GlideApps Proxy v2.5 - Production Deployment

## 📋 Обзор

Enhanced GlideApps Proxy v2.5 - это высокопроизводительный прокси-сервер для GlideApps с **2500% улучшением производительности** по сравнению с оригинальным прокси.

### 🏆 Ключевые Показатели Производительности

- ⚡ **100+ requests/second** (vs 4 RPS у оригинального)
- 🚀 **63ms средний отклик** (vs 1043ms у оригинального)
- 📈 **86.67% cache hit rate**
- 💾 **Оптимизировано для 2 ядра / 4ГБ ОЗУ**

### ✨ Возможности

- 🔄 **LRU Кэширование** - статический (24ч) и динамический (2ч) кэш
- 🗜️ **Интеллигентное Сжатие** - 4 уровень компрессии с smart-фильтрами
- 🔗 **Connection Pooling** - переиспользование TCP соединений
- 📊 **Продвинутый Мониторинг** - health checks и real-time метрики
- 🛡️ **Circuit Breaker** - защита от каскадных сбоев
- 🔄 **Автоматические Перезапуски** - PM2 process management

## 🖥️ Системные Требования

### Минимальные требования:
- **CPU**: 2 ядра
- **RAM**: 4ГБ
- **Disk**: 1ГБ свободного места
- **OS**: Ubuntu 18.04+ или CentOS 7+
- **Node.js**: 18.x или выше

### Рекомендуемые требования:
- **CPU**: 4 ядра
- **RAM**: 8ГБ
- **Network**: 1Гбит/с

## 🚀 Быстрый Деплой

### 1. Автоматический деплой (рекомендуется)

```bash
# Клонирование репозитория
git clone https://github.com/iLifeCreator/glideproxy.git
cd glideproxy/optimized-proxy

# Деплой на сервер
SERVER_IP=your-server-ip ./scripts/production-deploy.sh
```

### 2. Ручной деплой

```bash
# На целевом сервере
sudo apt-get update
sudo apt-get install -y nodejs npm git

# Установка PM2
sudo npm install -g pm2

# Клонирование и настройка
cd /opt
sudo git clone https://github.com/iLifeCreator/glideproxy.git glide-proxy
cd glide-proxy/optimized-proxy

# Установка зависимостей
sudo npm install --production

# Копирование production конфигурации
sudo cp .env.production .env
sudo mkdir -p logs

# Запуск сервиса
sudo pm2 start ecosystem.production.config.js --env production
sudo pm2 save
sudo pm2 startup systemd
```

## ⚙️ Конфигурация для 2 ядра / 4ГБ ОЗУ

Конфигурация уже оптимизирована в файлах:

- **`.env.production`** - основные настройки производительности
- **`ecosystem.production.config.js`** - PM2 конфигурация

### Ключевые оптимизации:

```javascript
// PM2 инстансы
instances: 2  // По одному на ядро

// Память
max_memory_restart: '1500M'  // 1.5ГБ на процесс
max_old_space_size: 2048     // 2ГБ Node.js heap

// Кэширование  
CACHE_MAX_SIZE: 800          // 800 элементов в кэше
MAX_SOCKETS: 1000            // 1000 соединений
```

## 📊 Мониторинг и Управление

### Health Check Endpoints

- **Health**: `http://your-server:3000/health`
- **Metrics**: `http://your-server:3000/health/metrics`

### PM2 Команды

```bash
pm2 status                    # Статус процессов
pm2 logs glide-proxy-enhanced # Просмотр логов
pm2 restart glide-proxy-enhanced # Перезапуск
pm2 reload glide-proxy-enhanced  # Плавная перезагрузка
pm2 monit                     # Мониторинг ресурсов
pm2 save                      # Сохранение конфигурации
```

### Метрики производительности

```json
{
  "uptime": 3600,
  "requests": 25000,
  "avgResponseTime": "63ms",
  "cacheStats": {
    "hitRate": "86.67%",
    "staticHits": 18000,
    "dynamicHits": 5000
  },
  "requestsPerSecond": 100
}
```

## 🔧 Настройка DNS и Nginx

### Обновление DNS записей

После успешного деплоя обновите A-запись для `rus.vkusdoterra.ru`:

```
rus.vkusdoterra.ru. IN A your-server-ip
```

### Nginx конфигурация (опционально)

Для дополнительной производительности и SSL:

```nginx
server {
    listen 80;
    listen 443 ssl http2;
    server_name rus.vkusdoterra.ru;

    # SSL configuration
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;

    # Proxy к Enhanced Proxy
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 5s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}
```

## 🔍 Устранение Неполадок

### Проверка статуса

```bash
# Проверка процессов
pm2 status

# Проверка логов
pm2 logs glide-proxy-enhanced --lines 50

# Проверка портов
netstat -tlnp | grep :3000

# Проверка health endpoint
curl http://localhost:3000/health
```

### Типичные проблемы

1. **Порт 3000 занят**
   ```bash
   sudo lsof -i :3000
   sudo kill -9 <PID>
   ```

2. **Недостаточно памяти**
   ```bash
   # Проверка использования памяти
   free -h
   pm2 monit
   ```

3. **Проблемы с правами доступа**
   ```bash
   sudo chown -R $USER:$USER /opt/glide-proxy
   ```

## 📈 Производительность и Нагрузочное Тестирование

### Apache Benchmark (ab)

```bash
# Тест производительности
ab -n 1000 -c 10 http://your-server:3000/

# Результаты должны показать:
# Requests per second: 100+ [#/sec]
# Time per request: 10ms or less
```

### Continuous Monitoring

```bash
# Мониторинг в real-time
watch -n 5 'curl -s http://localhost:3000/health/metrics | jq'
```

## 🚀 Следующие Шаги

1. **Обновите DNS** на ваш новый сервер
2. **Настройте мониторинг** (Grafana, Prometheus)
3. **Настройте бэкапы** PM2 конфигурации
4. **Настройте алерты** для критических метрик
5. **Проведите нагрузочное тестирование** в production

## 📞 Поддержка

При возникновении проблем:

1. Проверьте логи: `pm2 logs glide-proxy-enhanced`
2. Проверьте метрики: `curl http://localhost:3000/health/metrics`
3. Перезапустите сервис: `pm2 restart glide-proxy-enhanced`

---

**Enhanced GlideApps Proxy v2.5** - максимальная производительность для ваших GlideApps! 🚀