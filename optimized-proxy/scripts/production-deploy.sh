#!/bin/bash

# Production Deployment Script для Enhanced GlideApps Proxy
# Скрипт для деплоя на production сервер 2 ядра / 4ГБ ОЗУ

set -e

echo "🚀 Starting Enhanced GlideApps Proxy Production Deployment..."

# Проверка переменных окружения
if [ -z "$SERVER_IP" ]; then
    echo "❌ Ошибка: SERVER_IP не установлен"
    echo "Использование: SERVER_IP=your-server-ip ./production-deploy.sh"
    exit 1
fi

# Переменные
DEPLOY_USER="root"
DEPLOY_PATH="/opt/glide-proxy"
REPO_URL="https://github.com/iLifeCreator/glideproxy.git"
SERVICE_NAME="glide-proxy-enhanced"

echo "📡 Сервер: $SERVER_IP"
echo "📁 Путь деплоя: $DEPLOY_PATH"

# Функция для выполнения команд на удаленном сервере
remote_exec() {
    ssh -o StrictHostKeyChecking=no $DEPLOY_USER@$SERVER_IP "$1"
}

# Функция для копирования файлов
remote_copy() {
    scp -o StrictHostKeyChecking=no "$1" $DEPLOY_USER@$SERVER_IP:"$2"
}

echo "🔧 1. Подготовка сервера..."

# Установка Node.js и PM2 если не установлены
remote_exec "
    # Обновление пакетов
    apt-get update

    # Установка Node.js (если не установлен)
    if ! command -v node &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
    fi

    # Установка PM2 глобально (если не установлен)
    if ! command -v pm2 &> /dev/null; then
        npm install -g pm2
    fi

    # Создание директории для деплоя
    mkdir -p $DEPLOY_PATH
    chown $DEPLOY_USER:$DEPLOY_USER $DEPLOY_PATH
"

echo "📥 2. Клонирование/обновление репозитория..."

# Клонирование или обновление репозитория
remote_exec "
    cd $DEPLOY_PATH
    if [ -d '.git' ]; then
        echo 'Обновление существующего репозитория...'
        git fetch --all
        git reset --hard origin/main
        git pull origin main
    else
        echo 'Клонирование репозитория...'
        git clone $REPO_URL .
    fi
"

echo "📦 3. Установка зависимостей..."

# Установка зависимостей
remote_exec "
    cd $DEPLOY_PATH/optimized-proxy
    npm install --production --no-optional
"

echo "⚙️ 4. Настройка конфигурации..."

# Копирование production конфигурации
remote_exec "
    cd $DEPLOY_PATH/optimized-proxy
    cp .env.production .env
    mkdir -p logs
    chmod +x scripts/*.sh
"

echo "🔄 5. Остановка старого сервиса (если запущен)..."

# Остановка старых процессов
remote_exec "
    cd $DEPLOY_PATH/optimized-proxy
    pm2 delete $SERVICE_NAME 2>/dev/null || echo 'Старый сервис не найден'
    pm2 kill 2>/dev/null || echo 'PM2 daemon не запущен'
"

echo "🚀 6. Запуск нового сервиса..."

# Запуск сервиса с production конфигурацией
remote_exec "
    cd $DEPLOY_PATH/optimized-proxy
    pm2 start ecosystem.production.config.js --env production
    pm2 save
    pm2 startup systemd -u $DEPLOY_USER --hp /root
"

echo "🔍 7. Проверка статуса сервиса..."

# Проверка статуса
remote_exec "
    cd $DEPLOY_PATH/optimized-proxy
    sleep 5
    pm2 status
    pm2 logs $SERVICE_NAME --lines 10 --nostream
"

echo "🏥 8. Проверка health endpoint..."

# Проверка работоспособности
sleep 10
if remote_exec "curl -f http://localhost:3000/health > /dev/null 2>&1"; then
    echo "✅ Health check успешен!"
else
    echo "❌ Health check неуспешен. Проверьте логи:"
    remote_exec "pm2 logs $SERVICE_NAME --lines 20 --nostream"
    exit 1
fi

echo "🎉 Деплой завершен успешно!"
echo ""
echo "📊 Полезные команды для управления сервисом:"
echo "  pm2 status                     # Статус процессов"
echo "  pm2 logs $SERVICE_NAME         # Просмотр логов"
echo "  pm2 restart $SERVICE_NAME      # Перезапуск сервиса"
echo "  pm2 reload $SERVICE_NAME       # Плавная перезагрузка"
echo "  pm2 monit                      # Мониторинг"
echo ""
echo "🔗 URLs для проверки:"
echo "  http://$SERVER_IP:3000/health          # Health check"
echo "  http://$SERVER_IP:3000/health/metrics  # Метрики производительности"
echo ""
echo "🚀 Enhanced GlideApps Proxy успешно развернут на production!"