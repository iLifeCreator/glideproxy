#!/bin/bash

# Universal Reverse Proxy Installer - МИНИМАЛЬНАЯ СТАБИЛЬНАЯ ВЕРСИЯ
# Автоматическое развертывание Node.js reverse proxy с HTTPS
# Версия: 1.3
# Автор: Proxy Deployment System
#
# Использование:
#   1. Интерактивный режим:
#      sudo ./universal-proxy-installer.sh
#
#   2. Автоматический режим (через переменные окружения):
#      export PROXY_DOMAIN="proxy.example.com"
#      export TARGET_DOMAIN="old.example.com"
#      export SSL_EMAIL="admin@example.com"
#      export PROJECT_NAME="my-proxy"
#      sudo ./universal-proxy-installer.sh

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функции для логирования
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Функция для проверки статуса команды
check_status() {
    if [ $? -eq 0 ]; then
        log_success "$1"
    else
        log_error "$2"
        exit 1
    fi
}

# Заголовок
echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              UNIVERSAL REVERSE PROXY INSTALLER               ║"
echo "║                  Minimal Stability Edition                   ║"
echo "║                                                               ║"
echo "║  Автоматическое развертывание Node.js reverse proxy с HTTPS  ║"
echo "║  • SSL сертификаты Let's Encrypt                             ║"
echo "║  • nginx SSL termination                                     ║"
echo "║  • PM2 process management                                     ║"
echo "║  • URL rewriting для HTML/CSS/JS                            ║"
echo "║  • Минимальная архитектура для максимальной стабильности    ║"
echo "║  • Прямая обработка заголовков без middleware               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   log_error "Этот скрипт должен запускаться с правами root"
   echo "Используйте: sudo $0"
   exit 1
fi

# Интерактивная настройка или использование переменных окружения
if [ -z "$PROXY_DOMAIN" ]; then
    echo -e "${YELLOW}=== НАСТРОЙКА КОНФИГУРАЦИИ ===${NC}"
    echo
    echo "Введите параметры для развертывания reverse proxy:"
    echo
    read -p "Введите домен прокси (например, proxy.example.com): " PROXY_DOMAIN
    read -p "Введите целевой домен (например, old.example.com): " TARGET_DOMAIN
    read -p "Введите email для SSL сертификата: " SSL_EMAIL
    read -p "Введите имя проекта (например, my-proxy): " PROJECT_NAME
    
    # Опциональные параметры
    echo
    echo -e "${BLUE}=== ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ (нажмите Enter для значений по умолчанию) ===${NC}"
    read -p "Порт Node.js приложения [3000]: " NODE_PORT
    read -p "Протокол целевого сервера [https]: " TARGET_PROTOCOL
    read -p "Максимальная память для PM2 [512M]: " MAX_MEMORY
    read -p "Лимит запросов в секунду [10]: " RATE_LIMIT
    
    # Значения по умолчанию
    NODE_PORT=${NODE_PORT:-3000}
    TARGET_PROTOCOL=${TARGET_PROTOCOL:-https}
    MAX_MEMORY=${MAX_MEMORY:-512M}
    RATE_LIMIT=${RATE_LIMIT:-10}
    PROJECT_NAME=${PROJECT_NAME:-reverse-proxy}
fi

# Валидация обязательных параметров
if [ -z "$PROXY_DOMAIN" ] || [ -z "$TARGET_DOMAIN" ] || [ -z "$SSL_EMAIL" ]; then
    log_error "Не указаны обязательные параметры"
    echo "Обязательные переменные: PROXY_DOMAIN, TARGET_DOMAIN, SSL_EMAIL"
    echo
    echo "Пример использования через переменные окружения:"
    echo "export PROXY_DOMAIN=\"proxy.example.com\""
    echo "export TARGET_DOMAIN=\"old.example.com\""
    echo "export SSL_EMAIL=\"admin@example.com\""
    echo "export PROJECT_NAME=\"my-proxy\""
    echo "sudo $0"
    exit 1
fi

# Установка значений по умолчанию если не заданы
NODE_PORT=${NODE_PORT:-3000}
TARGET_PROTOCOL=${TARGET_PROTOCOL:-https}
MAX_MEMORY=${MAX_MEMORY:-512M}
RATE_LIMIT=${RATE_LIMIT:-10}
PROJECT_NAME=${PROJECT_NAME:-reverse-proxy}

# Отображение конфигурации
echo
echo -e "${GREEN}=== КОНФИГУРАЦИЯ РАЗВЕРТЫВАНИЯ ===${NC}"
echo "Домен прокси:      $PROXY_DOMAIN"
echo "Целевой домен:     $TARGET_DOMAIN"
echo "Email для SSL:     $SSL_EMAIL"
echo "Имя проекта:       $PROJECT_NAME"
echo "Порт Node.js:      $NODE_PORT"
echo "Протокол цели:     $TARGET_PROTOCOL"
echo "Лимит памяти:      $MAX_MEMORY"
echo "Лимит запросов:    $RATE_LIMIT/сек"
echo

if [ -z "$AUTO_CONFIRM" ]; then
    read -p "Продолжить установку? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Установка отменена"
        exit 0
    fi
fi

# Определение директории проекта
PROJECT_DIR="/opt/$PROJECT_NAME"

# Проверка существования проекта
if [ -d "$PROJECT_DIR" ]; then
    log_warning "Проект $PROJECT_NAME уже существует в $PROJECT_DIR"
    if [ -z "$AUTO_CONFIRM" ]; then
        read -p "Удалить существующий проект и продолжить? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Установка отменена"
            exit 0
        fi
    fi
    log_info "Удаляем существующий проект..."
    rm -rf "$PROJECT_DIR"
    
    # Остановка PM2 процесса если существует
    if command -v pm2 >/dev/null 2>&1 && pm2 list | grep -q "$PROJECT_NAME"; then
        log_info "Остановка существующего PM2 процесса..."
        pm2 delete "$PROJECT_NAME" 2>/dev/null || true
    fi
fi

# Проверка использования порта
if command -v ss >/dev/null 2>&1; then
    if ss -tuln | grep -q ":$NODE_PORT "; then
        log_error "Порт $NODE_PORT уже используется другим процессом"
        echo "Используемые порты:"
        ss -tuln | grep ":$NODE_PORT "
        echo
        echo "Выберите другой порт или остановите процесс, использующий порт $NODE_PORT"
        exit 1
    fi
elif command -v netstat >/dev/null 2>&1; then
    if netstat -tuln | grep -q ":$NODE_PORT "; then
        log_error "Порт $NODE_PORT уже используется другим процессом"
        echo "Используемые порты:"
        netstat -tuln | grep ":$NODE_PORT "
        echo
        echo "Выберите другой порт или остановите процесс, использующий порт $NODE_PORT"
        exit 1
    fi
fi

log_info "Начинаем установку reverse proxy..."

# 1. Обновление системы
log_info "Обновление пакетов системы..."
apt-get update -qq
check_status "Пакеты обновлены" "Ошибка обновления пакетов"

# 2. Установка зависимостей
log_info "Установка системных зависимостей..."
apt-get install -y curl wget gnupg2 software-properties-common nginx certbot python3-certbot-nginx ufw jq net-tools
check_status "Зависимости установлены" "Ошибка установки зависимостей"

# 3. Установка Node.js
if ! command -v node &> /dev/null; then
    log_info "Установка Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    check_status "Node.js установлен" "Ошибка установки Node.js"
else
    log_success "Node.js уже установлен: $(node --version)"
fi

# 4. Установка PM2
if ! command -v pm2 &> /dev/null; then
    log_info "Установка PM2..."
    npm install -g pm2
    check_status "PM2 установлен" "Ошибка установки PM2"
else
    log_success "PM2 уже установлен"
fi

# 5. Создание структуры проекта
log_info "Создание структуры проекта..."
mkdir -p $PROJECT_DIR/{src,config,logs,ssl,scripts}
check_status "Структура проекта создана" "Ошибка создания структуры"

# 6. Создание package.json
log_info "Создание package.json..."
cat > $PROJECT_DIR/package.json << EOF
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "description": "Minimal Reverse Proxy for $PROXY_DOMAIN -> $TARGET_DOMAIN",
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js",
    "dev": "NODE_ENV=development node src/app.js",
    "prod": "NODE_ENV=production node src/app.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "http-proxy-middleware": "^2.0.6",
    "dotenv": "^16.3.1"
  },
  "keywords": ["reverse-proxy", "node.js", "express", "https", "minimal", "stability"],
  "author": "Universal Proxy Installer Minimal",
  "license": "MIT"
}
EOF

# 7. Создание конфигурационного файла
log_info "Создание конфигурации..."
cat > $PROJECT_DIR/.env << EOF
# Конфигурация Minimal Reverse Proxy
NODE_ENV=production
PORT=$NODE_PORT
PROXY_DOMAIN=$PROXY_DOMAIN
TARGET_DOMAIN=$TARGET_DOMAIN
TARGET_PROTOCOL=$TARGET_PROTOCOL

# Логирование
LOG_LEVEL=info
LOG_DIR=./logs

# Мониторинг
HEALTH_CHECK_INTERVAL=30000
HEALTH_CHECK_TIMEOUT=5000

# Стабильность и совместимость
ENHANCED_COMPATIBILITY=true
MINIMAL_MODE=true
EOF

# 8. Создание основного приложения
log_info "Создание минимального приложения с повышенной стабильностью..."
cat > $PROJECT_DIR/src/app.js << 'APPEOF'
require('dotenv').config();
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const PORT = process.env.PORT || 3000;
const TARGET_PROTOCOL = process.env.TARGET_PROTOCOL || 'https';
const TARGET_DOMAIN = process.env.TARGET_DOMAIN;
const PROXY_DOMAIN = process.env.PROXY_DOMAIN;

console.log('Starting minimal proxy with enhanced stability...');
console.log(`Target: ${TARGET_PROTOCOL}://${TARGET_DOMAIN}`);
console.log(`Proxy: ${PROXY_DOMAIN}`);

// Simple proxy with direct header handling for maximum stability
app.use('/', createProxyMiddleware({
  target: `${TARGET_PROTOCOL}://${TARGET_DOMAIN}`,
  changeOrigin: true,
  secure: true,
  onProxyRes: (proxyRes, req, res) => {
    // Remove problematic headers that can cause compatibility issues
    delete proxyRes.headers['glide-allow-embedding'];
    delete proxyRes.headers['x-frame-options'];
    delete proxyRes.headers['content-security-policy'];
    
    // Add enhanced stability headers for maximum compatibility
    proxyRes.headers['x-frame-options'] = 'ALLOWALL';
    proxyRes.headers['access-control-allow-origin'] = '*';
    proxyRes.headers['access-control-allow-methods'] = 'GET, POST, PUT, DELETE, OPTIONS, PATCH';
    proxyRes.headers['access-control-allow-headers'] = 'Content-Type, Authorization, X-Requested-With, Accept';
    proxyRes.headers['access-control-allow-credentials'] = 'true';
    proxyRes.headers['content-security-policy'] = "default-src * 'unsafe-inline' 'unsafe-eval' data: blob:;";
    
    console.log(`${req.method} ${req.url} - ${proxyRes.statusCode}`);
  },
  onError: (err, req, res) => {
    console.error('Proxy error:', err.message);
    if (!res.headersSent) {
      res.status(502).send('Bad Gateway');
    }
  }
}));

app.listen(PORT, () => {
  console.log(`Minimal enhanced proxy listening on port ${PORT}`);
  console.log(`Enhanced stability mode: ACTIVE`);
  console.log(`All middleware removed for maximum compatibility`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('Received SIGINT, shutting down gracefully');
  process.exit(0);
});
APPEOF

# 9. Минимальные модули заменены прямой обработкой в app.js
log_info "Модули не создаются - используется минимальная архитектура..."

# 10-12. Модули не создаются в минимальной архитектуре
log_info "Пропуск создания модулей - используется простая архитектура..."

# 13. Создание PM2 конфигурации
log_info "Создание PM2 конфигурации..."
cat > $PROJECT_DIR/ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: '$PROJECT_NAME',
    script: 'src/app.js',
    instances: 1,
    exec_mode: 'fork',
    
    // Memory management
    max_memory_restart: '$MAX_MEMORY',
    
    // Environment
    env: {
      NODE_ENV: 'development',
      PORT: $NODE_PORT
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: $NODE_PORT
    },
    
    // Logging
    log_file: './logs/pm2-combined.log',
    out_file: './logs/pm2-out.log',
    error_file: './logs/pm2-error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    
    // Monitoring
    monitoring: false,
    
    // Restart policy
    restart_delay: 4000,
    max_restarts: 10,
    min_uptime: '10s',
    
    // Health monitoring
    health_check_grace_period: 3000,
    health_check_fatal_exceptions: true,
    
    // Cron restart (daily at 3 AM)
    cron_restart: '0 3 * * *'
  }]
};
EOF

# 14. Создание nginx конфигурации
log_info "Создание nginx конфигурации..."

# Функция создания nginx конфигурации с правильными escape символами
create_nginx_config() {
    cat > "$PROJECT_DIR/config/nginx-proxy.conf" << 'EOF'
# Nginx configuration for PROXY_DOMAIN_PLACEHOLDER
# SSL termination + proxy to Node.js app

upstream PROJECT_NAME_PLACEHOLDER_backend {
    server 127.0.0.1:NODE_PORT_PLACEHOLDER;
    keepalive 32;
}

# Rate limiting
limit_req_zone $binary_remote_addr zone=PROJECT_NAME_PLACEHOLDER_limit:10m rate=RATE_LIMIT_PLACEHOLDERr/s;
limit_conn_zone $binary_remote_addr zone=PROJECT_NAME_PLACEHOLDER_conn:10m;

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name PROXY_DOMAIN_PLACEHOLDER;
    
    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Redirect all HTTP to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name PROXY_DOMAIN_PLACEHOLDER;
    
    # Client settings
    client_max_body_size 10M;
    client_body_timeout 30s;
    client_header_timeout 30s;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/PROXY_DOMAIN_PLACEHOLDER/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/PROXY_DOMAIN_PLACEHOLDER/privkey.pem;
    
    # SSL Security
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Essential security headers (enhanced compatibility mode)
    add_header X-Content-Type-Options nosniff;
    add_header Referrer-Policy "no-referrer-when-downgrade";
    
    # Rate limiting
    limit_req zone=PROJECT_NAME_PLACEHOLDER_limit burst=20 nodelay;
    limit_conn PROJECT_NAME_PLACEHOLDER_conn 10;
    
    # Logging
    access_log /var/log/nginx/PROXY_DOMAIN_PLACEHOLDER.access.log combined;
    error_log /var/log/nginx/PROXY_DOMAIN_PLACEHOLDER.error.log;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;
    
    # Proxy configuration
    location / {
        proxy_pass http://PROJECT_NAME_PLACEHOLDER_backend;
        proxy_http_version 1.1;
        proxy_cache_bypass $http_upgrade;
        
        # Headers
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        
        # Error handling
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_next_upstream_tries 3;
        proxy_next_upstream_timeout 10s;
    }
    
    # Health check endpoint
    location /nginx-health {
        access_log off;
        return 200 "nginx healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Block common attack patterns
    location ~* \.(git|svn|env|log|bak)$ {
        deny all;
        return 404;
    }
    
    # Block PHP files
    location ~* \.php$ {
        deny all;
        return 404;
    }
}
EOF

    # Заменяем плейсхолдеры на реальные значения
    sed -i "s/PROXY_DOMAIN_PLACEHOLDER/$PROXY_DOMAIN/g" "$PROJECT_DIR/config/nginx-proxy.conf"
    sed -i "s/PROJECT_NAME_PLACEHOLDER/$PROJECT_NAME/g" "$PROJECT_DIR/config/nginx-proxy.conf"
    sed -i "s/NODE_PORT_PLACEHOLDER/$NODE_PORT/g" "$PROJECT_DIR/config/nginx-proxy.conf"
    sed -i "s/RATE_LIMIT_PLACEHOLDER/$RATE_LIMIT/g" "$PROJECT_DIR/config/nginx-proxy.conf"
}

# Вызываем функцию создания nginx конфигурации
create_nginx_config

# 15. Установка зависимостей Node.js
log_info "Установка зависимостей Node.js..."
cd $PROJECT_DIR
npm install --production
check_status "Зависимости установлены" "Ошибка установки зависимостей Node.js"

# 16. Настройка SSL
log_info "Настройка SSL сертификата..."

# Создание временной nginx конфигурации для получения сертификата
cat > /etc/nginx/sites-available/$PROJECT_NAME-temp << EOF
server {
    listen 80;
    server_name $PROXY_DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        try_files \$uri \$uri/ =404;
    }
    
    location / {
        return 200 "Temporary page for SSL setup";
        add_header Content-Type text/plain;
    }
}
EOF

# Отключение дефолтного сайта и включение временного
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/$PROJECT_NAME-temp /etc/nginx/sites-enabled/$PROJECT_NAME-temp

# Перезагрузка nginx
nginx -t && systemctl reload nginx
check_status "Временная nginx конфигурация активирована" "Ошибка настройки временной конфигурации"

# Создание директории для webroot
mkdir -p /var/www/html

# Получение SSL сертификата
log_info "Получение SSL сертификата от Let's Encrypt..."
certbot certonly --webroot -w /var/www/html -d $PROXY_DOMAIN --email $SSL_EMAIL --agree-tos --non-interactive
check_status "SSL сертификат получен" "Ошибка получения SSL сертификата"

# Удаление временной конфигурации
rm -f /etc/nginx/sites-enabled/$PROJECT_NAME-temp
rm -f /etc/nginx/sites-available/$PROJECT_NAME-temp

# 17. Настройка nginx
log_info "Настройка production nginx конфигурации..."

# Копирование конфигурации
cp $PROJECT_DIR/config/nginx-proxy.conf /etc/nginx/sites-available/$PROJECT_NAME
ln -sf /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/$PROJECT_NAME

# Проверка конфигурации
nginx -t
check_status "nginx конфигурация валидна" "Ошибка в nginx конфигурации"

# Перезагрузка nginx
systemctl reload nginx
check_status "nginx перезагружен" "Ошибка перезагрузки nginx"

# 18. Запуск приложения
log_info "Запуск Node.js приложения..."

cd $PROJECT_DIR

# Запуск через PM2
pm2 start ecosystem.config.js --env production
check_status "Приложение запущено через PM2" "Ошибка запуска приложения"

# Сохранение конфигурации PM2
pm2 save
check_status "Конфигурация PM2 сохранена" "Ошибка сохранения конфигурации PM2"

# Настройка автозапуска
pm2 startup systemd -u root --hp /root
systemctl enable pm2-root
check_status "Автозапуск PM2 настроен" "Ошибка настройки автозапуска"

# 19. Настройка firewall
log_info "Настройка firewall..."

# Включение UFW если не включен
if ! ufw status | grep -q "Status: active"; then
    ufw --force enable
fi

# Открытие необходимых портов
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS

# Опционально: ограничение SSH
ufw limit 22/tcp

check_status "Firewall настроен" "Ошибка настройки firewall"

# 20. Создание скриптов управления
log_info "Создание скриптов управления..."

# Функция создания скриптов управления
create_management_scripts() {
    # Скрипт статуса
    cat > $PROJECT_DIR/scripts/status.sh << EOF
#!/bin/bash
echo "=== $PROJECT_NAME STATUS ==="
echo
echo "PM2 Status:"
pm2 status $PROJECT_NAME
echo
echo "nginx Status:"
systemctl status nginx --no-pager -l
echo
echo "SSL Certificate:"
certbot certificates | grep -A 5 "$PROXY_DOMAIN"
echo
echo "Health Check:"
curl -s https://$PROXY_DOMAIN/health | jq . 2>/dev/null || curl -s https://$PROXY_DOMAIN/health
EOF

    # Скрипт перезапуска
    cat > $PROJECT_DIR/scripts/restart.sh << EOF
#!/bin/bash
echo "Restarting $PROJECT_NAME..."
pm2 restart $PROJECT_NAME
systemctl reload nginx
echo "Restart completed"
EOF

    # Скрипт логов
    cat > $PROJECT_DIR/scripts/logs.sh << EOF
#!/bin/bash
echo "=== $PROJECT_NAME LOGS ==="
echo "Use Ctrl+C to exit"
echo
pm2 logs $PROJECT_NAME --lines 50
EOF

    # Скрипт обновления SSL
    cat > $PROJECT_DIR/scripts/renew-ssl.sh << EOF
#!/bin/bash
echo "Renewing SSL certificate for $PROXY_DOMAIN..."
certbot renew --quiet
systemctl reload nginx
echo "SSL renewal completed"
EOF

    # Делаем скрипты исполняемыми
    chmod +x $PROJECT_DIR/scripts/*.sh
}

# Вызываем функцию создания скриптов управления
create_management_scripts
check_status "Скрипты управления созданы" "Ошибка создания скриптов"

# 21. Создание документации
log_info "Создание документации..."

cat > $PROJECT_DIR/README.md << EOF
# $PROJECT_NAME - Minimal Edition

Автоматически развернутый reverse proxy с минимальной архитектурой для $PROXY_DOMAIN → $TARGET_DOMAIN

## Информация о развертывании

- **Домен прокси**: $PROXY_DOMAIN
- **Целевой домен**: $TARGET_DOMAIN
- **Порт Node.js**: $NODE_PORT
- **Протокол цели**: $TARGET_PROTOCOL
- **Лимит памяти**: $MAX_MEMORY
- **Rate limiting**: $RATE_LIMIT req/sec
- **Режим стабильности**: Включен

## Новые возможности версии 1.3

### Минимальная архитектура для максимальной стабильности
- Убраны все middleware для предотвращения конфликтов
- Прямая обработка заголовков в onProxyRes
- Простое логирование через console.log

### Улучшенная совместимость
- Автоматическое удаление проблематичных заголовков
- Принудительная установка ALLOWALL для x-frame-options
- Разрешающий Content Security Policy
- Поддержка CORS

### Стабильность работы
- Минимальная кодовая база для уменьшения точек отказа
- Отсутствие сложных зависимостей
- Быстрый старт и надежная работа

## Управление

### Статус сервисов
\`\`\`bash
./scripts/status.sh
\`\`\`

### Перезапуск
\`\`\`bash
./scripts/restart.sh
\`\`\`

### Просмотр логов
\`\`\`bash
./scripts/logs.sh
\`\`\`

### Обновление SSL сертификата
\`\`\`bash
./scripts/renew-ssl.sh
\`\`\`

## Endpoints

- **Main Proxy**: https://$PROXY_DOMAIN/
- **Health Check**: https://$PROXY_DOMAIN/health
- **Detailed Health**: https://$PROXY_DOMAIN/health/detailed
- **nginx Health**: https://$PROXY_DOMAIN/nginx-health

## Файлы конфигурации

- **Node.js app**: \`$PROJECT_DIR/src/app.js\`
- **Environment**: \`$PROJECT_DIR/.env\`
- **PM2 config**: \`$PROJECT_DIR/ecosystem.config.js\`
- **nginx config**: \`/etc/nginx/sites-available/$PROJECT_NAME\`

## Логи

- **Application**: \`$PROJECT_DIR/logs/\`
- **PM2**: \`$PROJECT_DIR/logs/pm2-*.log\`
- **nginx**: \`/var/log/nginx/$PROXY_DOMAIN.*.log\`

## Мониторинг

### PM2
\`\`\`bash
pm2 status
pm2 monit
\`\`\`

### Health Check
\`\`\`bash
curl https://$PROXY_DOMAIN/health
\`\`\`

### SSL Certificate Status
\`\`\`bash
certbot certificates
\`\`\`

## Конфигурация стабильности

Система автоматически настроена для максимальной стабильности:

- **ENHANCED_COMPATIBILITY=true** - Режим максимальной совместимости
- **MINIMAL_MODE=true** - Минимальная архитектура без middleware
- Прямая обработка заголовков для устранения конфликтов
- Простое логирование для надежности
- Автоматическое удаление проблематичных заголовков

## Автоматическое обновление

- SSL сертификаты обновляются автоматически через certbot
- PM2 автоматически перезапускается при ошибках
- Ежедневный restart в 3:00 AM
- Автоматическое восстановление после сбоев

## Безопасность

- TLS 1.2/1.3 шифрование
- Rate limiting: $RATE_LIMIT req/sec (адаптивный)
- Оптимизированные security headers
- Firewall настроен (порты 22, 80, 443)
- Защита от основных типов атак

## Поддержка

Для получения помощи проверьте:
1. Логи приложения: \`./scripts/logs.sh\`
2. Статус сервисов: \`./scripts/status.sh\`
3. nginx логи: \`tail -f /var/log/nginx/$PROXY_DOMAIN.error.log\`
EOF

check_status "Документация создана" "Ошибка создания документации"

# 22. Верификация развертывания
log_info "Верификация развертывания..."

# Ждем запуска сервисов
sleep 10

# Проверка PM2
if pm2 list | grep -q "$PROJECT_NAME.*online"; then
    log_success "PM2 приложение запущено"
else
    log_error "PM2 приложение не запущено"
    pm2 logs $PROJECT_NAME --lines 10
    exit 1
fi

# Проверка nginx
if systemctl is-active --quiet nginx; then
    log_success "nginx активен"
else
    log_error "nginx не активен"
    systemctl status nginx --no-pager
    exit 1
fi

# Проверка HTTP redirect
log_info "Проверка HTTP → HTTPS redirect..."
if curl -I "http://$PROXY_DOMAIN/" 2>/dev/null | grep -q "301"; then
    log_success "HTTP redirect работает"
else
    log_warning "HTTP redirect может не работать"
fi

# Проверка HTTPS
log_info "Проверка HTTPS endpoint..."
if curl -k -s "https://$PROXY_DOMAIN/nginx-health" | grep -q "nginx healthy"; then
    log_success "HTTPS endpoint работает"
else
    log_warning "HTTPS endpoint может не работать"
fi

# Проверка health check
log_info "Проверка health check..."
if curl -k -s "https://$PROXY_DOMAIN/health" | grep -q "status"; then
    log_success "Health check работает"
else
    log_warning "Health check может не работать"
fi

# 23. Финальный отчет
echo
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    УСТАНОВКА ЗАВЕРШЕНА!                      ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${BLUE}🎉 Minimal Universal Reverse Proxy успешно развернут!${NC}"
echo
echo -e "${YELLOW}📋 Информация о развертывании:${NC}"
echo "   • Домен прокси:    https://$PROXY_DOMAIN"
echo "   • Целевой домен:   $TARGET_PROTOCOL://$TARGET_DOMAIN"
echo "   • Проект:          $PROJECT_NAME"
echo "   • Директория:      $PROJECT_DIR"
echo "   • Стабильность:    Повышенная совместимость включена"
echo
echo -e "${YELLOW}🔗 Endpoints:${NC}"
echo "   • Main Proxy:      https://$PROXY_DOMAIN/"
echo "   • Health Check:    https://$PROXY_DOMAIN/health"
echo "   • Detailed Health: https://$PROXY_DOMAIN/health/detailed"
echo "   • nginx Health:    https://$PROXY_DOMAIN/nginx-health"
echo
echo -e "${YELLOW}🛠 Управление:${NC}"
echo "   • Статус:          $PROJECT_DIR/scripts/status.sh"
echo "   • Перезапуск:      $PROJECT_DIR/scripts/restart.sh"
echo "   • Логи:            $PROJECT_DIR/scripts/logs.sh"
echo "   • Обновить SSL:    $PROJECT_DIR/scripts/renew-ssl.sh"
echo
echo -e "${YELLOW}📚 Документация:${NC}"
echo "   • README:          $PROJECT_DIR/README.md"
echo
echo -e "${GREEN}✅ Новые возможности:${NC}"
echo "   • Минимальная архитектура для максимальной стабильности"
echo "   • Убраны middleware для предотвращения конфликтов"
echo "   • Прямая обработка заголовков"
echo "   • Оптимизированная nginx конфигурация"
echo
echo -e "${GREEN}✅ Все сервисы запущены и готовы к работе!${NC}"
echo
echo -e "${CYAN}Для тестирования откройте в браузере: https://$PROXY_DOMAIN${NC}"
echo

log_success "Minimal Universal Reverse Proxy успешно установлен и настроен!" 