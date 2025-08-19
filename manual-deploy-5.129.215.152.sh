#!/bin/bash

# Ручной деплой Enhanced GlideApps Proxy v2.5
# Сервер: 5.129.215.152 (2 ядра / 4ГБ ОЗУ)

SERVER_IP="5.129.215.152"
DEPLOY_USER="root"
DEPLOY_PATH="/opt/glide-proxy"

echo "🔧 Ручной деплой на сервер $SERVER_IP"

echo "📋 Выполните следующие команды на сервере $SERVER_IP:"
echo ""

echo "# 1. Подготовка сервера"
cat << 'EOF'
# Обновление системы
sudo apt-get update && sudo apt-get upgrade -y

# Установка Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Проверка версии Node.js
node --version
npm --version

# Установка PM2 глобально
sudo npm install -g pm2

# Установка Git (если не установлен)
sudo apt-get install -y git curl
EOF

echo ""
echo "# 2. Клонирование репозитория"
cat << 'EOF'
# Создание директории и клонирование
sudo mkdir -p /opt
cd /opt
sudo git clone https://github.com/iLifeCreator/glideproxy.git glide-proxy
cd glide-proxy/optimized-proxy

# Установка зависимостей
sudo npm install --production --no-optional

# Создание логов директории
sudo mkdir -p logs
EOF

echo ""
echo "# 3. Конфигурация для 2 ядра / 4ГБ ОЗУ"
cat << 'EOF'
# Копирование production конфигурации
sudo cp .env.production .env

# Проверка конфигурации
cat .env

# Сделать скрипты исполняемыми
sudo chmod +x scripts/*.sh
EOF

echo ""
echo "# 4. Остановка старых процессов (если есть)"
cat << 'EOF'
# Остановка старых прокси процессов
sudo pkill -f "node.*proxy" || echo "Старые процессы не найдены"
sudo pm2 delete all 2>/dev/null || echo "PM2 процессы не найдены"
sudo pm2 kill 2>/dev/null || echo "PM2 daemon не запущен"
EOF

echo ""
echo "# 5. Запуск Enhanced Proxy"
cat << 'EOF'
# Запуск с PM2 production конфигурацией
sudo pm2 start ecosystem.production.config.js --env production

# Проверка статуса
sudo pm2 status

# Сохранение конфигурации
sudo pm2 save

# Настройка автозапуска
sudo pm2 startup systemd
EOF

echo ""
echo "# 6. Проверка работоспособности"
cat << 'EOF'
# Проверка портов
sudo netstat -tlnp | grep :3000

# Health check
curl http://localhost:3000/health

# Просмотр метрик
curl http://localhost:3000/health/metrics

# Просмотр логов
sudo pm2 logs glide-proxy-enhanced --lines 20
EOF

echo ""
echo "# 7. Настройка Firewall (UFW)"
cat << 'EOF'
# Настройка firewall
sudo ufw allow 22/tcp
sudo ufw allow 3000/tcp
sudo ufw --force enable
sudo ufw status
EOF

echo ""
echo "✅ После выполнения всех команд Enhanced Proxy будет доступен:"
echo "🔗 Health: http://5.129.215.152:3000/health"
echo "📊 Metrics: http://5.129.215.152:3000/health/metrics"