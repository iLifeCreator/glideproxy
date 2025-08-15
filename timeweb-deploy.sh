#!/bin/bash

# TimeWeb VPS Quick Deploy Script for Enhanced Proxy Server v2.0
# Скрипт быстрого развертывания для VPS TimeWeb
# Version: 2.0
# GitHub: https://github.com/iLifeCreator/glideproxy

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# ASCII Art Logo
print_logo() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║     ███████╗███╗   ██╗██╗  ██╗ █████╗ ███╗   ██╗ ██████╗███████╗║"
    echo "║     ██╔════╝████╗  ██║██║  ██║██╔══██╗████╗  ██║██╔════╝██╔════╝║"
    echo "║     █████╗  ██╔██╗ ██║███████║███████║██╔██╗ ██║██║     █████╗  ║"
    echo "║     ██╔══╝  ██║╚██╗██║██╔══██║██╔══██║██║╚██╗██║██║     ██╔══╝  ║"
    echo "║     ███████╗██║ ╚████║██║  ██║██║  ██║██║ ╚████║╚██████╗███████╗║"
    echo "║     ╚══════╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝║"
    echo "║                                                                  ║"
    echo "║            PROXY SERVER v2.0 - TimeWeb VPS Edition              ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Функции логирования
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_step() {
    echo -e "\n${MAGENTA}━━━ $1 ━━━${NC}\n"
}

# Проверка root прав
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Этот скрипт должен запускаться с правами root"
        echo "Используйте: sudo $0"
        exit 1
    fi
}

# Определение системы
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        log_error "Не удалось определить операционную систему"
        exit 1
    fi
    
    log_info "Обнаружена система: $OS $VER"
    
    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        log_warning "Скрипт оптимизирован для Ubuntu/Debian. Продолжить?"
        read -p "Продолжить? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Определение ресурсов VPS
detect_resources() {
    CPU_CORES=$(nproc)
    TOTAL_RAM=$(free -m | awk 'NR==2{print $2}')
    DISK_SIZE=$(df -h / | awk 'NR==2{print $2}')
    
    log_info "Обнаружены ресурсы VPS:"
    echo "  • CPU ядер: $CPU_CORES"
    echo "  • RAM: ${TOTAL_RAM}MB"
    echo "  • Диск: $DISK_SIZE"
    
    # Автоматическая оптимизация на основе ресурсов
    if [ $TOTAL_RAM -lt 2048 ]; then
        PROFILE="minimal"
        RECOMMENDED_WORKERS=2
        RECOMMENDED_MEMORY="256M"
        RECOMMENDED_SOCKETS=500
    elif [ $TOTAL_RAM -lt 4096 ]; then
        PROFILE="standard"
        RECOMMENDED_WORKERS=$((CPU_CORES > 2 ? CPU_CORES : 2))
        RECOMMENDED_MEMORY="400M"
        RECOMMENDED_SOCKETS=1000
    else
        PROFILE="performance"
        RECOMMENDED_WORKERS=$CPU_CORES
        RECOMMENDED_MEMORY="512M"
        RECOMMENDED_SOCKETS=2000
    fi
    
    log_info "Рекомендуемый профиль: ${GREEN}$PROFILE${NC}"
}

# Интерактивная конфигурация
configure_interactive() {
    echo
    log_step "КОНФИГУРАЦИЯ PROXY СЕРВЕРА"
    
    # Основные параметры
    echo -e "${YELLOW}Введите обязательные параметры:${NC}"
    echo
    
    read -p "1. Домен для прокси (например, proxy.yourdomain.com): " PROXY_DOMAIN
    while [[ -z "$PROXY_DOMAIN" ]]; do
        log_error "Домен не может быть пустым"
        read -p "   Домен для прокси: " PROXY_DOMAIN
    done
    
    read -p "2. Целевой домен (например, example.com): " TARGET_DOMAIN
    while [[ -z "$TARGET_DOMAIN" ]]; do
        log_error "Целевой домен не может быть пустым"
        read -p "   Целевой домен: " TARGET_DOMAIN
    done
    
    read -p "3. Email для SSL сертификата: " SSL_EMAIL
    while [[ -z "$SSL_EMAIL" ]]; do
        log_error "Email не может быть пустым"
        read -p "   Email для SSL: " SSL_EMAIL
    done
    
    read -p "4. Имя проекта [proxy-server]: " PROJECT_NAME
    PROJECT_NAME=${PROJECT_NAME:-proxy-server}
    
    echo
    echo -e "${YELLOW}Дополнительные параметры (Enter для рекомендуемых):${NC}"
    echo
    
    read -p "5. Количество worker процессов [$RECOMMENDED_WORKERS]: " WORKERS
    WORKERS=${WORKERS:-$RECOMMENDED_WORKERS}
    
    read -p "6. Память на worker [$RECOMMENDED_MEMORY]: " MAX_MEMORY
    MAX_MEMORY=${MAX_MEMORY:-$RECOMMENDED_MEMORY}
    
    read -p "7. Максимум соединений [$RECOMMENDED_SOCKETS]: " MAX_SOCKETS
    MAX_SOCKETS=${MAX_SOCKETS:-$RECOMMENDED_SOCKETS}
    
    read -p "8. Протокол целевого сервера [https]: " TARGET_PROTOCOL
    TARGET_PROTOCOL=${TARGET_PROTOCOL:-https}
    
    # Вывод конфигурации
    echo
    log_step "ПРОВЕРКА КОНФИГУРАЦИИ"
    echo -e "${CYAN}┌─────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│          Ваша конфигурация              │${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} Proxy домен: ${GREEN}$PROXY_DOMAIN${NC}"
    echo -e "${CYAN}│${NC} Целевой домен: ${GREEN}$TARGET_DOMAIN${NC}"
    echo -e "${CYAN}│${NC} SSL Email: ${GREEN}$SSL_EMAIL${NC}"
    echo -e "${CYAN}│${NC} Проект: ${GREEN}$PROJECT_NAME${NC}"
    echo -e "${CYAN}│${NC} Workers: ${GREEN}$WORKERS${NC}"
    echo -e "${CYAN}│${NC} Память: ${GREEN}$MAX_MEMORY${NC}"
    echo -e "${CYAN}│${NC} Соединения: ${GREEN}$MAX_SOCKETS${NC}"
    echo -e "${CYAN}│${NC} Протокол: ${GREEN}$TARGET_PROTOCOL${NC}"
    echo -e "${CYAN}│${NC} Профиль: ${GREEN}$PROFILE${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────┘${NC}"
    echo
    
    read -p "Все верно? Начать установку? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Установка отменена"
        exit 1
    fi
}

# Основная установка
install_proxy() {
    log_step "НАЧАЛО УСТАНОВКИ"
    
    # Экспорт переменных для установщика
    export PROXY_DOMAIN
    export TARGET_DOMAIN
    export SSL_EMAIL
    export PROJECT_NAME
    export WORKERS
    export MAX_MEMORY
    export MAX_SOCKETS
    export TARGET_PROTOCOL
    export NODE_PORT=3000
    export RATE_LIMIT=50
    export COMPRESSION_LEVEL=6
    export ENABLE_CACHING=true
    export ENABLE_CIRCUIT_BREAKER=true
    export ENABLE_METRICS=true
    export KEEP_ALIVE_TIMEOUT=60000
    
    # Создание рабочей директории
    log_info "Создание рабочей директории..."
    mkdir -p /opt/proxy-installer
    cd /opt/proxy-installer
    
    # Загрузка установщика
    log_info "Загрузка Enhanced Proxy Server v2.0..."
    curl -sSL -o enhanced-installer-v2.sh \
        https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/enhanced-installer-v2.sh
    
    if [ ! -f enhanced-installer-v2.sh ]; then
        log_error "Не удалось загрузить установщик"
        exit 1
    fi
    
    chmod +x enhanced-installer-v2.sh
    log_success "Установщик загружен"
    
    # Запуск установщика
    log_info "Запуск установки Enhanced Proxy Server..."
    ./enhanced-installer-v2.sh
    
    if [ $? -eq 0 ]; then
        log_success "Установка завершена успешно!"
    else
        log_error "Произошла ошибка при установке"
        exit 1
    fi
}

# Проверка установки
verify_installation() {
    log_step "ПРОВЕРКА УСТАНОВКИ"
    
    # Проверка PM2
    log_info "Проверка PM2..."
    if pm2 status | grep -q online; then
        log_success "PM2 работает"
        pm2 status
    else
        log_error "PM2 не запущен"
        return 1
    fi
    
    echo
    
    # Проверка nginx
    log_info "Проверка nginx..."
    if systemctl is-active --quiet nginx; then
        log_success "nginx работает"
    else
        log_error "nginx не запущен"
        return 1
    fi
    
    # Проверка health endpoint
    log_info "Проверка health endpoint..."
    if curl -s http://localhost:3000/health | grep -q healthy; then
        log_success "Приложение отвечает"
        echo
        curl -s http://localhost:3000/health | python3 -m json.tool 2>/dev/null || \
        curl -s http://localhost:3000/health
    else
        log_error "Приложение не отвечает"
        return 1
    fi
    
    return 0
}

# Информация после установки
post_install_info() {
    log_step "УСТАНОВКА ЗАВЕРШЕНА"
    
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Enhanced Proxy Server v2.0 установлен!                ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    echo -e "${CYAN}📋 Информация о развертывании:${NC}"
    echo "├─ Proxy URL: ${GREEN}https://$PROXY_DOMAIN${NC}"
    echo "├─ Target: ${GREEN}$TARGET_PROTOCOL://$TARGET_DOMAIN${NC}"
    echo "├─ Директория: ${GREEN}/opt/$PROJECT_NAME${NC}"
    echo "├─ Workers: ${GREEN}$WORKERS${NC}"
    echo "└─ Профиль: ${GREEN}$PROFILE${NC}"
    echo
    
    echo -e "${CYAN}🔗 Endpoints:${NC}"
    echo "├─ Main Proxy: ${GREEN}https://$PROXY_DOMAIN/${NC}"
    echo "├─ Health Check: ${GREEN}https://$PROXY_DOMAIN/health${NC}"
    echo "└─ nginx Health: ${GREEN}https://$PROXY_DOMAIN/nginx-health${NC}"
    echo
    
    echo -e "${CYAN}📂 Управление:${NC}"
    echo "├─ Директория: ${YELLOW}cd /opt/$PROJECT_NAME${NC}"
    echo "├─ Статус: ${YELLOW}./scripts/status.sh${NC}"
    echo "├─ Логи: ${YELLOW}./scripts/logs.sh${NC}"
    echo "├─ Перезапуск: ${YELLOW}./scripts/restart.sh${NC}"
    echo "└─ Мониторинг: ${YELLOW}pm2 monit${NC}"
    echo
    
    echo -e "${CYAN}⚡ Команды PM2:${NC}"
    echo "├─ pm2 status    - статус процессов"
    echo "├─ pm2 logs      - просмотр логов"
    echo "├─ pm2 restart all - перезапуск"
    echo "└─ pm2 monit     - мониторинг"
    echo
    
    echo -e "${YELLOW}📝 Следующие шаги:${NC}"
    echo "1. Проверьте работу через браузер: ${GREEN}https://$PROXY_DOMAIN${NC}"
    echo "2. Проверьте health endpoint: ${GREEN}curl https://$PROXY_DOMAIN/health${NC}"
    echo "3. При необходимости настройте мониторинг"
    echo "4. Сделайте backup конфигурации: ${YELLOW}cp /opt/$PROJECT_NAME/.env ~/proxy-backup.env${NC}"
    echo
    
    echo -e "${GREEN}✅ Enhanced Proxy Server v2.0 готов к работе!${NC}"
    echo
    
    # Сохранение информации об установке
    cat > ~/proxy-install-info.txt << EOF
Enhanced Proxy Server v2.0 - Installation Info
Date: $(date)
===============================================
Proxy Domain: https://$PROXY_DOMAIN
Target: $TARGET_PROTOCOL://$TARGET_DOMAIN
Project: /opt/$PROJECT_NAME
Workers: $WORKERS
Profile: $PROFILE
===============================================
Commands:
- Status: cd /opt/$PROJECT_NAME && ./scripts/status.sh
- Logs: cd /opt/$PROJECT_NAME && ./scripts/logs.sh
- Restart: cd /opt/$PROJECT_NAME && ./scripts/restart.sh
===============================================
EOF
    
    log_info "Информация об установке сохранена в ~/proxy-install-info.txt"
}

# Главная функция
main() {
    clear
    print_logo
    
    log_info "Запуск TimeWeb VPS Deploy Script v2.0"
    echo
    
    # Проверки
    check_root
    detect_system
    detect_resources
    
    # Конфигурация
    configure_interactive
    
    # Установка
    install_proxy
    
    # Проверка
    if verify_installation; then
        post_install_info
    else
        log_error "Установка завершена с ошибками. Проверьте логи."
        echo "Логи PM2: pm2 logs"
        echo "Логи nginx: sudo tail /var/log/nginx/error.log"
        exit 1
    fi
}

# Обработка сигналов
trap 'echo -e "\n${YELLOW}Установка прервана пользователем${NC}"; exit 1' INT TERM

# Запуск
main "$@"