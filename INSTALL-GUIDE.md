# 📘 Полная инструкция по установке Enhanced Proxy Server v2.0 на TimeWeb VPS

## 🎯 Подготовка VPS

### 1. Создание VPS в TimeWeb

1. Войдите в панель управления TimeWeb
2. Создайте новый VPS со следующими параметрами:
   - **OS**: Ubuntu 22.04 LTS (рекомендуется) или Ubuntu 20.04 LTS
   - **Тариф**: Минимум 2 vCPU, 2GB RAM
   - **Диск**: 20GB SSD или больше
   - **Локация**: Выберите ближайшую к вашей аудитории

### 2. Настройка DNS

1. В панели управления доменом добавьте A-запись:
   ```
   Тип: A
   Имя: proxy (или @ для корневого домена)
   Значение: IP_АДРЕС_ВАШЕГО_VPS
   TTL: 3600
   ```

2. Дождитесь распространения DNS (5-30 минут)

3. Проверьте:
   ```bash
   nslookup proxy.yourdomain.com
   ```

## 🚀 Установка Enhanced Proxy v2.0

### Вариант 1: Быстрая установка (рекомендуется)

1. **Подключитесь к VPS через SSH:**
   ```bash
   ssh root@YOUR_VPS_IP
   ```

2. **Запустите one-liner установщик:**
   ```bash
   curl -sSL https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/quick-install.sh | sudo bash
   ```

3. **Следуйте интерактивным инструкциям:**
   - Введите домен для прокси (например: proxy.yourdomain.com)
   - Введите целевой домен (например: target-site.com)
   - Введите email для SSL сертификата
   - Выберите имя проекта
   - Нажмите Enter для автоматических настроек

### Вариант 2: Установка с кастомными параметрами

1. **Подключитесь к VPS:**
   ```bash
   ssh root@YOUR_VPS_IP
   ```

2. **Обновите систему:**
   ```bash
   apt update && apt upgrade -y
   ```

3. **Скачайте установщик:**
   ```bash
   cd /opt
   curl -O https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/enhanced-installer-v2.sh
   chmod +x enhanced-installer-v2.sh
   ```

4. **Настройте параметры и запустите:**
   ```bash
   export PROXY_DOMAIN="proxy.yourdomain.com"
   export TARGET_DOMAIN="example.com"
   export SSL_EMAIL="admin@yourdomain.com"
   export PROJECT_NAME="my-proxy"
   export WORKERS="auto"
   export MAX_MEMORY="512M"
   export ENABLE_CACHING="true"
   export ENABLE_CIRCUIT_BREAKER="true"
   
   sudo ./enhanced-installer-v2.sh
   ```

### Вариант 3: Установка для конкретного сценария

Выберите готовую конфигурацию из примеров:

#### Для небольшого сайта (VPS 2 vCPU, 2GB RAM):
```bash
curl -sSL https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/enhanced-installer-v2.sh | \
PROXY_DOMAIN="proxy.yourdomain.com" \
TARGET_DOMAIN="target.com" \
SSL_EMAIL="admin@yourdomain.com" \
PROJECT_NAME="small-proxy" \
WORKERS=2 \
MAX_MEMORY="400M" \
MAX_SOCKETS=1000 \
sudo bash
```

#### Для высоконагруженного проекта (VPS 4+ vCPU, 4GB+ RAM):
```bash
curl -sSL https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/enhanced-installer-v2.sh | \
PROXY_DOMAIN="proxy.yourdomain.com" \
TARGET_DOMAIN="target.com" \
SSL_EMAIL="admin@yourdomain.com" \
PROJECT_NAME="performance-proxy" \
WORKERS=4 \
MAX_MEMORY="800M" \
MAX_SOCKETS=3000 \
COMPRESSION_LEVEL=3 \
sudo bash
```

## ✅ Проверка установки

### 1. Проверьте статус сервисов:

```bash
# PM2 процессы
pm2 status

# nginx
systemctl status nginx

# Health check
curl http://localhost:3000/health
```

### 2. Проверьте через браузер:

Откройте в браузере:
- `https://proxy.yourdomain.com` - основной прокси
- `https://proxy.yourdomain.com/health` - статус сервера

### 3. Проверьте SSL сертификат:

```bash
# Проверка сертификата
certbot certificates

# Проверка через браузер - должен показывать замок
```

## 🔧 Настройка после установки

### Изменение конфигурации:

1. **Перейдите в директорию проекта:**
   ```bash
   cd /opt/your-project-name
   ```

2. **Отредактируйте конфигурацию:**
   ```bash
   nano .env
   ```

3. **Примените изменения:**
   ```bash
   pm2 restart all
   ```

### Основные команды управления:

```bash
# Статус
./scripts/status.sh

# Перезапуск
./scripts/restart.sh

# Логи
./scripts/logs.sh

# Мониторинг
pm2 monit
```

## 📊 Тестирование производительности

### 1. Установите тестовый скрипт:

```bash
cd /opt/your-project-name
curl -O https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/performance-test.js
chmod +x performance-test.js
```

### 2. Запустите тест:

```bash
# Быстрый тест
TEST_URL=https://proxy.yourdomain.com \
TEST_DURATION=30 \
TEST_CONNECTIONS=100 \
node performance-test.js
```

## 🛡️ Безопасность

### Настройка Firewall:

```bash
# Базовая настройка
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
```

### Настройка Fail2ban (опционально):

```bash
# Установка
apt install fail2ban -y

# Конфигурация
cat > /etc/fail2ban/jail.local << 'EOF'
[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 10
findtime = 60
bantime = 3600
EOF

# Перезапуск
systemctl restart fail2ban
```

## 🔄 Обновление

Для обновления до последней версии:

```bash
# Backup конфигурации
cp /opt/your-project-name/.env ~/proxy-backup.env

# Обновление
cd /opt
curl -O https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/enhanced-installer-v2.sh
chmod +x enhanced-installer-v2.sh
sudo ./enhanced-installer-v2.sh
```

## 🐛 Решение проблем

### Проблема: 502 Bad Gateway

```bash
# Проверьте PM2
pm2 status
pm2 restart all

# Проверьте логи
pm2 logs --err
```

### Проблема: Не получается SSL сертификат

```bash
# Проверьте DNS
nslookup proxy.yourdomain.com

# Получите сертификат вручную
certbot certonly --nginx -d proxy.yourdomain.com
```

### Проблема: Медленная работа

```bash
# Проверьте нагрузку
htop

# Проверьте метрики
curl http://localhost:3000/health | jq '.metrics'

# Увеличьте workers
nano /opt/your-project-name/.env
# Измените WORKERS=4
pm2 restart all
```

## 📱 Мониторинг через Telegram (опционально)

### Настройка уведомлений:

```bash
# Установите PM2 Telegram модуль
pm2 install pm2-telegram-notify

# Настройте
pm2 set pm2-telegram-notify:bot_token YOUR_BOT_TOKEN
pm2 set pm2-telegram-notify:chat_id YOUR_CHAT_ID
```

## 📈 Оптимизация для разных VPS TimeWeb

### VPS Start (1 vCPU, 1GB RAM):
```env
WORKERS=1
MAX_MEMORY=256M
MAX_SOCKETS=300
COMPRESSION_LEVEL=6
```

### VPS Standard (2 vCPU, 2GB RAM):
```env
WORKERS=2
MAX_MEMORY=400M
MAX_SOCKETS=1000
COMPRESSION_LEVEL=6
```

### VPS Business (4 vCPU, 4GB RAM):
```env
WORKERS=4
MAX_MEMORY=800M
MAX_SOCKETS=2000
COMPRESSION_LEVEL=6
```

### VPS Professional (8 vCPU, 8GB RAM):
```env
WORKERS=8
MAX_MEMORY=800M
MAX_SOCKETS=5000
COMPRESSION_LEVEL=3
```

## ✅ Чек-лист после установки

- [ ] PM2 показывает все процессы "online"
- [ ] HTTPS работает с валидным сертификатом
- [ ] Health endpoint возвращает "healthy"
- [ ] Целевой сайт открывается через прокси
- [ ] Логи не содержат критических ошибок
- [ ] Firewall настроен и активен
- [ ] Сделан backup конфигурации

## 📞 Поддержка

### TimeWeb:
- Панель управления: https://hosting.timeweb.ru/
- Техподдержка: через тикеты в панели

### Enhanced Proxy:
- GitHub: https://github.com/iLifeCreator/glideproxy/issues
- Документация: https://github.com/iLifeCreator/glideproxy

## 🎉 Готово!

Ваш Enhanced Proxy Server v2.0 установлен и готов к работе!

Проверьте работу: `https://proxy.yourdomain.com`

---

**Enhanced Proxy Server v2.0** - Максимальная производительность для вашего VPS! 🚀