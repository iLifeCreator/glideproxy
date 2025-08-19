#!/bin/bash

##############################################################################
# Ultra-Optimized Proxy Installer
# Автоматическая установка и настройка высокопроизводительного прокси-сервера
##############################################################################

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация по умолчанию
DEFAULT_PORT=3000
DEFAULT_TARGET_DOMAIN=""
DEFAULT_PROXY_DOMAIN=""
DEFAULT_INSTALL_DIR="/opt/ultra-proxy"
DEFAULT_USER="proxy"
DEFAULT_NODE_VERSION="18"

# Функции для вывода
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

# Проверка прав root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Не запускайте этот скрипт от root. Используйте sudo для отдельных команд."
        exit 1
    fi
}

# Определение операционной системы
detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        log_info "Обнаружена ОС: $OS $VER"
    else
        log_error "Не удалось определить операционную систему"
        exit 1
    fi
}

# Проверка зависимостей
check_dependencies() {
    log_info "Проверка зависимостей..."
    
    local missing_deps=()
    
    # Проверяем основные утилиты
    for cmd in curl wget git; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=($cmd)
        fi
    done
    
    if [[ ${#missing_deps[@]} -ne 0 ]]; then
        log_warning "Отсутствуют зависимости: ${missing_deps[*]}"
        log_info "Устанавливаем недостающие пакеты..."
        
        case $OS in
            ubuntu|debian)
                sudo apt-get update
                sudo apt-get install -y "${missing_deps[@]}"
                ;;
            centos|rhel|fedora)
                sudo yum install -y "${missing_deps[@]}"
                ;;
            *)
                log_error "Неподдерживаемая ОС для автоматической установки зависимостей"
                exit 1
                ;;
        esac
    fi
    
    log_success "Зависимости проверены"
}

# Установка Node.js
install_nodejs() {
    log_info "Проверка Node.js..."
    
    if command -v node &> /dev/null; then
        local node_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ $node_version -ge 14 ]]; then
            log_success "Node.js уже установлен: $(node --version)"
            return 0
        else
            log_warning "Установлена устаревшая версия Node.js: $(node --version)"
        fi
    fi
    
    log_info "Устанавливаем Node.js $DEFAULT_NODE_VERSION..."
    
    # Использование NodeSource репозитория
    curl -fsSL https://deb.nodesource.com/setup_${DEFAULT_NODE_VERSION}.x | sudo -E bash -
    
    case $OS in
        ubuntu|debian)
            sudo apt-get install -y nodejs
            ;;
        centos|rhel|fedora)
            sudo yum install -y nodejs npm
            ;;
    esac
    
    # Проверка установки
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        log_success "Node.js установлен: $(node --version), npm: $(npm --version)"
    else
        log_error "Ошибка установки Node.js"
        exit 1
    fi
}

# Установка PM2
install_pm2() {
    log_info "Устанавливаем PM2..."
    
    if command -v pm2 &> /dev/null; then
        log_success "PM2 уже установлен: $(pm2 --version)"
        return 0
    fi
    
    sudo npm install -g pm2
    
    # Настройка автозапуска PM2
    sudo pm2 startup systemd -u $USER --hp /home/$USER
    
    log_success "PM2 установлен и настроен"
}

# Создание пользователя для прокси
create_user() {
    if id "$DEFAULT_USER" &>/dev/null; then
        log_info "Пользователь $DEFAULT_USER уже существует"
    else
        log_info "Создаем пользователя $DEFAULT_USER..."
        sudo useradd -r -s /bin/false -d $DEFAULT_INSTALL_DIR -m $DEFAULT_USER
        log_success "Пользователь $DEFAULT_USER создан"
    fi
}

# Получение конфигурации от пользователя
get_configuration() {
    log_info "Настройка конфигурации..."
    
    echo
    read -p "Target domain (например, app.vkusdoterra.ru): " TARGET_DOMAIN
    read -p "Proxy domain (например, rus.vkusdoterra.ru): " PROXY_DOMAIN
    read -p "Port [${DEFAULT_PORT}]: " PORT
    read -p "Директория установки [${DEFAULT_INSTALL_DIR}]: " INSTALL_DIR
    
    # Значения по умолчанию
    TARGET_DOMAIN=${TARGET_DOMAIN:-$DEFAULT_TARGET_DOMAIN}
    PROXY_DOMAIN=${PROXY_DOMAIN:-$DEFAULT_PROXY_DOMAIN}
    PORT=${PORT:-$DEFAULT_PORT}
    INSTALL_DIR=${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}
    
    # Валидация
    if [[ -z "$TARGET_DOMAIN" || -z "$PROXY_DOMAIN" ]]; then
        log_error "TARGET_DOMAIN и PROXY_DOMAIN обязательны для заполнения"
        exit 1
    fi
    
    log_info "Конфигурация:"
    log_info "  Target Domain: $TARGET_DOMAIN"
    log_info "  Proxy Domain: $PROXY_DOMAIN"
    log_info "  Port: $PORT"
    log_info "  Install Directory: $INSTALL_DIR"
    
    echo
    read -p "Продолжить установку? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Установка отменена"
        exit 0
    fi
}

# Установка приложения
install_application() {
    log_info "Устанавливаем приложение в $INSTALL_DIR..."
    
    # Создание директории
    sudo mkdir -p $INSTALL_DIR
    
    # Копирование файлов (предполагается, что скрипт запущен из директории проекта)
    local current_dir=$(pwd)
    log_info "Копируем файлы из $current_dir..."
    
    sudo cp -r "$current_dir"/* $INSTALL_DIR/
    sudo chown -R $DEFAULT_USER:$DEFAULT_USER $INSTALL_DIR
    
    # Создание .env файла
    log_info "Создаем конфигурационный файл..."
    
    sudo -u $DEFAULT_USER tee $INSTALL_DIR/.env > /dev/null <<EOF
# Ultra-Optimized Proxy Configuration
NODE_ENV=production
PORT=$PORT
TARGET_PROTOCOL=https
TARGET_DOMAIN=$TARGET_DOMAIN
PROXY_DOMAIN=$PROXY_DOMAIN

# Performance settings
WORKERS=auto
MAX_SOCKETS=2000
MAX_FREE_SOCKETS=512

# Timeouts
KEEP_ALIVE_TIMEOUT=30000
HEADERS_TIMEOUT=35000
REQUEST_TIMEOUT=15000
CONNECT_TIMEOUT=5000

# Caching
CACHE_MAX_AGE=7200
CACHE_MAX_SIZE=500
STATIC_CACHE_AGE=86400

# Compression
COMPRESSION_LEVEL=4
COMPRESSION_THRESHOLD=512

# Monitoring
ENABLE_METRICS=true
ENABLE_HEALTH_CHECK=true
LOG_LEVEL=info

# Node.js optimizations
UV_THREADPOOL_SIZE=16
NODE_OPTIONS="--max-old-space-size=1024 --optimize-for-size"
EOF
    
    log_success "Конфигурационный файл создан"
}

# Установка зависимостей npm
install_npm_dependencies() {
    log_info "Устанавливаем npm зависимости..."
    
    cd $INSTALL_DIR
    sudo -u $DEFAULT_USER npm install --production --no-optional
    
    log_success "Зависимости установлены"
}

# Настройка systemd сервиса
setup_systemd_service() {
    log_info "Настраиваем systemd сервис..."
    
    sudo tee /etc/systemd/system/ultra-proxy.service > /dev/null <<EOF
[Unit]
Description=Ultra-Optimized Proxy Server
Documentation=https://github.com/ultra-proxy/ultra-proxy
After=network.target

[Service]
Type=notify
User=$DEFAULT_USER
Group=$DEFAULT_USER
Environment=PATH=/usr/bin:/usr/local/bin
Environment=NODE_ENV=production
ExecStart=/usr/bin/node $INSTALL_DIR/src/ultra-optimized-proxy.js
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=mixed
KillSignal=SIGINT
TimeoutStopSec=5
Restart=always
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3
WorkingDirectory=$INSTALL_DIR

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable ultra-proxy
    
    log_success "Systemd сервис настроен"
}

# Настройка PM2
setup_pm2() {
    log_info "Настраиваем PM2..."
    
    cd $INSTALL_DIR
    
    # Запуск через PM2
    sudo -u $DEFAULT_USER pm2 start ecosystem.config.js --env production
    sudo -u $DEFAULT_USER pm2 save
    
    log_success "PM2 настроен"
}

# Настройка firewall
setup_firewall() {
    log_info "Настраиваем firewall..."
    
    if command -v ufw &> /dev/null; then
        sudo ufw allow $PORT/tcp
        log_success "UFW правило добавлено для порта $PORT"
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-port=$PORT/tcp
        sudo firewall-cmd --reload
        log_success "Firewalld правило добавлено для порта $PORT"
    else
        log_warning "Firewall не обнаружен. Убедитесь, что порт $PORT открыт"
    fi
}

# Системные оптимизации
apply_system_optimizations() {
    log_info "Применяем системные оптимизации..."
    
    # Увеличение лимитов файловых дескрипторов
    sudo tee -a /etc/security/limits.conf > /dev/null <<EOF

# Ultra-Proxy optimizations
$DEFAULT_USER soft nofile 65536
$DEFAULT_USER hard nofile 65536
* soft nofile 65536
* hard nofile 65536
EOF
    
    # Оптимизация сетевого стека
    sudo tee -a /etc/sysctl.conf > /dev/null <<EOF

# Ultra-Proxy network optimizations
net.core.somaxconn = 65536
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 20
net.ipv4.tcp_fin_timeout = 30
EOF
    
    sudo sysctl -p
    
    log_success "Системные оптимизации применены"
}

# Проверка установки
verify_installation() {
    log_info "Проверяем установку..."
    
    # Проверка сервиса
    if systemctl is-active --quiet ultra-proxy; then
        log_success "Сервис ultra-proxy запущен"
    else
        log_warning "Сервис ultra-proxy не запущен. Запускаем..."
        sudo systemctl start ultra-proxy
        sleep 3
        
        if systemctl is-active --quiet ultra-proxy; then
            log_success "Сервис ultra-proxy успешно запущен"
        else
            log_error "Не удалось запустить сервис"
            sudo journalctl -u ultra-proxy --no-pager -l
            return 1
        fi
    fi
    
    # Проверка доступности
    log_info "Проверяем доступность прокси..."
    if curl -s --max-time 10 http://localhost:$PORT/health > /dev/null; then
        log_success "Прокси-сервер отвечает на порту $PORT"
    else
        log_error "Прокси-сервер недоступен на порту $PORT"
        return 1
    fi
    
    return 0
}

# Вывод информации о завершении
show_completion_info() {
    log_success "Установка завершена успешно!"
    
    echo
    echo "=========================================="
    echo "  Ultra-Optimized Proxy Server v3.0"
    echo "=========================================="
    echo
    echo "📍 Установлен в: $INSTALL_DIR"
    echo "🔗 Прокси URL: http://localhost:$PORT"
    echo "🎯 Target: https://$TARGET_DOMAIN"
    echo "🌐 Proxy Domain: $PROXY_DOMAIN"
    echo
    echo "🛠️  Управление сервисом:"
    echo "   sudo systemctl start ultra-proxy"
    echo "   sudo systemctl stop ultra-proxy"
    echo "   sudo systemctl restart ultra-proxy"
    echo "   sudo systemctl status ultra-proxy"
    echo
    echo "📊 Мониторинг:"
    echo "   curl http://localhost:$PORT/health"
    echo "   curl http://localhost:$PORT/health/metrics"
    echo "   sudo journalctl -u ultra-proxy -f"
    echo
    echo "📝 Конфигурация: $INSTALL_DIR/.env"
    echo "📋 Логи: sudo journalctl -u ultra-proxy"
    echo
    echo "🚀 Для настройки Nginx frontend см. README.md"
    echo
}

# Основная функция
main() {
    echo "=========================================="
    echo "  Ultra-Optimized Proxy Installer v3.0"
    echo "=========================================="
    echo
    
    check_root
    detect_os
    check_dependencies
    install_nodejs
    install_pm2
    create_user
    get_configuration
    install_application
    install_npm_dependencies
    setup_systemd_service
    setup_firewall
    apply_system_optimizations
    
    if verify_installation; then
        show_completion_info
    else
        log_error "Установка завершилась с ошибками. Проверьте логи."
        exit 1
    fi
}

# Обработка сигналов
trap 'log_error "Установка прервана"; exit 1' INT TERM

# Запуск установки
main "$@"