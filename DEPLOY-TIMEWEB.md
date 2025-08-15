# 📋 Инструкция по установке Enhanced Proxy Server v2.0 на VPS TimeWeb

## 🎯 Требования

### Минимальные требования VPS:
- **OS**: Ubuntu 20.04/22.04 LTS (рекомендуется)
- **CPU**: 2 vCPU (минимум), 4 vCPU (рекомендуется)
- **RAM**: 2 GB (минимум), 4 GB (рекомендуется)
- **Disk**: 20 GB SSD
- **Network**: 100 Mbps+

### Подготовка домена:
- Домен должен быть направлен на IP вашего VPS
- DNS записи должны быть настроены (A запись)

## 🚀 Быстрая установка (One-liner)

Подключитесь к VPS через SSH и выполните:

```bash
curl -sSL https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/enhanced-installer-v2.sh | \
PROXY_DOMAIN="your-proxy.domain.com" \
TARGET_DOMAIN="target.domain.com" \
SSL_EMAIL="your-email@domain.com" \
PROJECT_NAME="my-proxy" \
WORKERS="auto" \
sudo bash
```

## 📝 Пошаговая установка

### Шаг 1: Подключение к VPS

```bash
# Подключитесь к вашему VPS через SSH
ssh root@YOUR_VPS_IP

# Или если у вас есть пользователь
ssh username@YOUR_VPS_IP
```

### Шаг 2: Обновление системы

```bash
# Обновите систему
sudo apt update && sudo apt upgrade -y

# Установите базовые утилиты
sudo apt install -y curl wget git htop
```

### Шаг 3: Клонирование репозитория

```bash
# Создайте рабочую директорию
sudo mkdir -p /opt/proxy-installer
cd /opt/proxy-installer

# Клонируйте репозиторий
sudo git clone https://github.com/iLifeCreator/glideproxy.git .

# Или скачайте только установщик
sudo curl -O https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/enhanced-installer-v2.sh
sudo chmod +x enhanced-installer-v2.sh
```

### Шаг 4: Настройка конфигурации

#### Вариант A: Интерактивная установка

```bash
# Запустите установщик в интерактивном режиме
sudo ./enhanced-installer-v2.sh

# Следуйте инструкциям и введите:
# - Домен прокси (например: proxy.yourdomain.com)
# - Целевой домен (например: target-site.com)
# - Email для SSL сертификата
# - Имя проекта
# - Дополнительные параметры (или Enter для значений по умолчанию)
```

#### Вариант B: Автоматическая установка с параметрами

```bash
# Создайте файл конфигурации
sudo nano install-config.sh
```

Добавьте следующее содержимое:

```bash
#!/bin/bash

# Основные параметры (ОБЯЗАТЕЛЬНО ИЗМЕНИТЕ!)
export PROXY_DOMAIN="proxy.yourdomain.com"      # Ваш домен для прокси
export TARGET_DOMAIN="example.com"              # Целевой сайт
export SSL_EMAIL="admin@yourdomain.com"         # Email для Let's Encrypt
export PROJECT_NAME="my-proxy"                  # Имя проекта

# Параметры производительности
export WORKERS="auto"                           # auto = количество CPU ядер
export MAX_MEMORY="512M"                        # Память на worker
export MAX_SOCKETS="1000"                       # Макс. соединений
export KEEP_ALIVE_TIMEOUT="60000"              # Keep-alive timeout (мс)

# Оптимизации
export ENABLE_CACHING="true"                    # Включить кэширование
export ENABLE_CIRCUIT_BREAKER="true"           # Включить circuit breaker
export ENABLE_METRICS="true"                    # Включить метрики
export COMPRESSION_LEVEL="6"                    # Уровень сжатия (0-9)
export RATE_LIMIT="50"                         # Лимит запросов/сек с одного IP

# Запуск установщика
sudo ./enhanced-installer-v2.sh
```

Сохраните и запустите:

```bash
# Сделайте файл исполняемым
sudo chmod +x install-config.sh

# Запустите установку
sudo ./install-config.sh
```

### Шаг 5: Проверка установки

После завершения установки проверьте работу:

```bash
# Проверка статуса PM2
pm2 status

# Проверка nginx
sudo systemctl status nginx

# Проверка health endpoint
curl http://localhost:3000/health

# Проверка через домен (после настройки DNS)
curl https://your-proxy.domain.com/health
```

## ⚙️ Оптимизация для TimeWeb VPS

### Для VPS с 2 vCPU, 2GB RAM:

```bash
export WORKERS=2
export MAX_MEMORY=400M
export MAX_SOCKETS=500
export COMPRESSION_LEVEL=6
export RATE_LIMIT=30
```

### Для VPS с 4 vCPU, 4GB RAM:

```bash
export WORKERS=4
export MAX_MEMORY=800M
export MAX_SOCKETS=2000
export COMPRESSION_LEVEL=6
export RATE_LIMIT=100
```

### Для VPS с 8 vCPU, 8GB RAM:

```bash
export WORKERS=8
export MAX_MEMORY=800M
export MAX_SOCKETS=5000
export COMPRESSION_LEVEL=3
export RATE_LIMIT=200
```

## 🔧 Управление после установки

### Директория проекта
```bash
cd /opt/your-project-name
```

### Основные команды

```bash
# Проверка статуса
./scripts/status.sh

# Перезапуск сервисов
./scripts/restart.sh

# Просмотр логов
./scripts/logs.sh

# Мониторинг производительности
./scripts/performance.sh

# Очистка кэша
./scripts/clear-cache.sh
```

### PM2 команды

```bash
# Статус процессов
pm2 status

# Мониторинг в реальном времени
pm2 monit

# Логи
pm2 logs --lines 100

# Перезапуск
pm2 restart all

# Graceful reload
pm2 reload all
```

## 📊 Мониторинг

### Health Check
```bash
# Локально
curl http://localhost:3000/health | jq .

# Через домен
curl https://your-proxy.domain.com/health | jq .
```

### Метрики производительности
```bash
# Просмотр метрик
curl https://your-proxy.domain.com/health | jq '.metrics'

# Сброс метрик
curl -X POST https://your-proxy.domain.com/health/reset
```

## 🧪 Тестирование производительности

После установки протестируйте производительность:

```bash
# Установите тестовый скрипт
cd /opt/your-project-name
sudo curl -O https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/performance-test.js
sudo chmod +x performance-test.js

# Запустите тест
TEST_URL=https://your-proxy.domain.com \
TEST_DURATION=30 \
TEST_CONNECTIONS=100 \
node performance-test.js
```

## 🛡️ Безопасность

### Настройка Firewall

```bash
# Проверка статуса UFW
sudo ufw status

# Если не настроен, выполните:
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw --force enable
```

### Fail2ban (опционально)

```bash
# Установка fail2ban
sudo apt install fail2ban -y

# Настройка для nginx
sudo nano /etc/fail2ban/jail.local
```

Добавьте:
```ini
[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 10
findtime = 60
bantime = 3600
```

```bash
# Перезапуск fail2ban
sudo systemctl restart fail2ban
```

## 🔄 Обновление

Для обновления до последней версии:

```bash
# Перейдите в директорию
cd /opt/proxy-installer

# Обновите репозиторий
sudo git pull

# Или скачайте последнюю версию установщика
sudo curl -O https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/enhanced-installer-v2.sh
sudo chmod +x enhanced-installer-v2.sh

# Запустите обновление
sudo ./enhanced-installer-v2.sh
```

## 🐛 Troubleshooting

### Проблема: Не получается SSL сертификат

```bash
# Проверьте, что домен направлен на сервер
nslookup your-proxy.domain.com

# Проверьте доступность порта 80
sudo netstat -tlnp | grep :80

# Попробуйте получить сертификат вручную
sudo certbot certonly --nginx -d your-proxy.domain.com
```

### Проблема: 502 Bad Gateway

```bash
# Проверьте, запущено ли приложение
pm2 status

# Проверьте логи
pm2 logs --err

# Перезапустите приложение
pm2 restart all
```

### Проблема: Высокая нагрузка

```bash
# Проверьте использование ресурсов
htop

# Проверьте метрики
curl http://localhost:3000/health | jq '.metrics'

# Увеличьте количество workers
cd /opt/your-project-name
nano .env
# Измените WORKERS=4 (или больше)
pm2 restart all
```

### Проблема: Медленные ответы

```bash
# Включите кэширование если отключено
echo "ENABLE_CACHING=true" >> /opt/your-project-name/.env

# Увеличьте количество сокетов
echo "MAX_SOCKETS=2000" >> /opt/your-project-name/.env

# Перезапустите
pm2 restart all
```

## 📱 Контакты TimeWeb Support

Если возникли проблемы с VPS:
- **Панель управления**: https://hosting.timeweb.ru/
- **Техподдержка**: через тикет-систему в панели
- **База знаний**: https://timeweb.com/ru/help/

## ✅ Checklist после установки

- [ ] Проверьте `pm2 status` - все процессы должны быть `online`
- [ ] Проверьте `curl https://your-domain/health` - должен вернуть `{"status":"healthy"}`
- [ ] Проверьте SSL: `https://your-domain` должен открываться с валидным сертификатом
- [ ] Проверьте логи: `pm2 logs --lines 50` не должно быть критических ошибок
- [ ] Протестируйте производительность: `node performance-test.js`
- [ ] Настройте мониторинг (опционально)
- [ ] Сделайте backup конфигурации: `cp /opt/your-project/.env /root/proxy-backup.env`

## 🎉 Готово!

После успешной установки ваш Enhanced Proxy Server v2.0 будет доступен по адресу:
```
https://your-proxy.domain.com
```

Endpoints:
- **Main Proxy**: `https://your-proxy.domain.com/`
- **Health Check**: `https://your-proxy.domain.com/health`
- **nginx Health**: `https://your-proxy.domain.com/nginx-health`

---

**Enhanced Proxy Server v2.0** - Оптимизирован для максимальной производительности! 🚀