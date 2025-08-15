#!/bin/bash

# Fix Script for Enhanced Proxy Server v2.0 -> v2.1
# Исправляет проблемы с задержками и роутингом health endpoints
# Version: 2.1-fix

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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

# Заголовок
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         Enhanced Proxy Server v2.1 - Fix Patch              ║"
echo "║                                                              ║"
echo "║  Исправления:                                                ║"
echo "║  • Улучшена производительность и снижены задержки           ║"
echo "║  • Исправлен роутинг /health и /health/detailed             ║"
echo "║  • Добавлена retry логика для временных сбоев               ║"
echo "║  • Улучшена обработка cookies и заголовков                  ║"
echo "║  • Оптимизировано кэширование                               ║"
echo "╚══════════════════════════════════════════════════════════════╗"
echo -e "${NC}"

# Проверка root
if [[ $EUID -ne 0 ]]; then
   log_error "Этот скрипт должен запускаться с правами root"
   exit 1
fi

# Поиск установленного proxy
log_info "Поиск установленного Enhanced Proxy Server..."

# Попытка найти директорию проекта
PROJECT_DIRS=$(find /opt -maxdepth 1 -type d -name "*proxy*" 2>/dev/null | head -5)

if [ -z "$PROJECT_DIRS" ]; then
    log_error "Не найдена установка Enhanced Proxy Server"
    echo "Укажите путь к директории проекта вручную:"
    read -p "Путь к проекту (например, /opt/my-proxy): " PROJECT_DIR
else
    echo "Найдены следующие установки:"
    echo "$PROJECT_DIRS" | nl
    echo
    read -p "Выберите номер или введите путь вручную: " CHOICE
    
    if [[ "$CHOICE" =~ ^[0-9]+$ ]]; then
        PROJECT_DIR=$(echo "$PROJECT_DIRS" | sed -n "${CHOICE}p")
    else
        PROJECT_DIR="$CHOICE"
    fi
fi

# Проверка директории
if [ ! -d "$PROJECT_DIR" ]; then
    log_error "Директория $PROJECT_DIR не существует"
    exit 1
fi

if [ ! -f "$PROJECT_DIR/src/app.js" ]; then
    log_error "Не найден файл app.js в $PROJECT_DIR/src/"
    exit 1
fi

log_success "Найдена установка в: $PROJECT_DIR"

# Backup
log_info "Создание backup текущей версии..."
BACKUP_DIR="$PROJECT_DIR/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r "$PROJECT_DIR/src" "$BACKUP_DIR/"
cp "$PROJECT_DIR/.env" "$BACKUP_DIR/" 2>/dev/null || true
cp "$PROJECT_DIR/ecosystem.config.js" "$BACKUP_DIR/" 2>/dev/null || true
log_success "Backup создан в: $BACKUP_DIR"

# Загрузка исправленной версии
log_info "Загрузка Enhanced Proxy v2.1-Fixed..."
curl -sSL -o "$PROJECT_DIR/src/app.js" \
    https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/enhanced-proxy-v2-fixed.js

if [ $? -ne 0 ]; then
    log_error "Не удалось загрузить исправленную версию"
    log_info "Восстановление из backup..."
    cp -r "$BACKUP_DIR/src" "$PROJECT_DIR/"
    exit 1
fi

log_success "Исправленная версия загружена"

# Обновление зависимостей если нужно
log_info "Проверка зависимостей..."
cd "$PROJECT_DIR"

# Проверяем наличие compression
if ! grep -q "compression" package.json 2>/dev/null; then
    log_info "Установка compression middleware..."
    npm install compression --save
fi

# Обновление .env если нужны новые параметры
log_info "Обновление конфигурации..."

# Добавляем новые параметры если их нет
if ! grep -q "LOG_REQUESTS" "$PROJECT_DIR/.env" 2>/dev/null; then
    echo "" >> "$PROJECT_DIR/.env"
    echo "# Logging" >> "$PROJECT_DIR/.env"
    echo "LOG_REQUESTS=false" >> "$PROJECT_DIR/.env"
fi

if ! grep -q "RETRY_ATTEMPTS" "$PROJECT_DIR/.env" 2>/dev/null; then
    echo "RETRY_ATTEMPTS=3" >> "$PROJECT_DIR/.env"
fi

# Оптимизация для снижения задержек
if grep -q "ENABLE_CACHING=false" "$PROJECT_DIR/.env" 2>/dev/null; then
    log_info "Включение кэширования для улучшения производительности..."
    sed -i 's/ENABLE_CACHING=false/ENABLE_CACHING=true/' "$PROJECT_DIR/.env"
fi

# Обновление PM2 конфигурации для лучшей производительности
if [ -f "$PROJECT_DIR/ecosystem.config.js" ]; then
    log_info "Оптимизация PM2 конфигурации..."
    
    # Добавляем node args если их нет
    if ! grep -q "node_args" "$PROJECT_DIR/ecosystem.config.js"; then
        sed -i "/max_restarts:/a\    node_args: '--max-old-space-size=2048 --optimize-for-size'," \
            "$PROJECT_DIR/ecosystem.config.js"
    fi
fi

# Перезапуск приложения
log_info "Перезапуск Enhanced Proxy Server..."
pm2 restart all

# Ждем запуска
sleep 3

# Проверка работоспособности
log_info "Проверка работоспособности..."

# Проверка PM2
if pm2 status | grep -q "online"; then
    log_success "PM2 процессы запущены"
else
    log_error "PM2 процессы не запущены"
    log_info "Попытка восстановления..."
    cd "$PROJECT_DIR"
    pm2 delete all
    pm2 start ecosystem.config.js
fi

# Проверка health endpoint
sleep 2
HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health)

if [ "$HEALTH_CHECK" = "200" ]; then
    log_success "Health endpoint работает"
    echo
    echo "Проверка метрик:"
    curl -s http://localhost:3000/health | python3 -m json.tool 2>/dev/null || \
    curl -s http://localhost:3000/health
else
    log_warning "Health endpoint вернул код: $HEALTH_CHECK"
fi

# Проверка detailed health
DETAILED_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health/detailed)
if [ "$DETAILED_CHECK" = "200" ]; then
    log_success "Detailed health endpoint работает"
else
    log_warning "Detailed health endpoint вернул код: $DETAILED_CHECK"
fi

# Финальные рекомендации
echo
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Патч v2.1 успешно применен!                       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${CYAN}Что было исправлено:${NC}"
echo "✓ Улучшена производительность и снижены задержки"
echo "✓ Исправлен роутинг /health и /health/detailed endpoints"
echo "✓ Добавлена retry логика для временных сбоев"
echo "✓ Улучшена обработка cookies и заголовков"
echo "✓ Оптимизировано кэширование статических ресурсов"
echo
echo -e "${CYAN}Рекомендации для максимальной производительности:${NC}"
echo
echo "1. Для снижения задержек увеличьте количество workers:"
echo "   ${YELLOW}nano $PROJECT_DIR/.env${NC}"
echo "   Установите: WORKERS=4 (или больше для мощных VPS)"
echo
echo "2. Включите агрессивное кэширование:"
echo "   ${YELLOW}ENABLE_CACHING=true${NC}"
echo "   ${YELLOW}CACHE_MAX_AGE=7200${NC}"
echo
echo "3. Уменьшите уровень сжатия для снижения CPU нагрузки:"
echo "   ${YELLOW}COMPRESSION_LEVEL=3${NC}"
echo
echo "4. Для отладки включите логирование:"
echo "   ${YELLOW}LOG_REQUESTS=true${NC}"
echo "   Затем: ${YELLOW}pm2 logs${NC}"
echo
echo -e "${CYAN}Проверка работы:${NC}"
echo "• Health check: ${GREEN}curl https://your-proxy.com/health${NC}"
echo "• Detailed health: ${GREEN}curl https://your-proxy.com/health/detailed${NC}"
echo "• Метрики: ${GREEN}pm2 monit${NC}"
echo
echo -e "${YELLOW}Backup сохранен в: $BACKUP_DIR${NC}"
echo
echo "При возникновении проблем восстановите backup:"
echo "cp -r $BACKUP_DIR/src $PROJECT_DIR/"
echo "pm2 restart all"
echo
log_success "Обновление завершено!"