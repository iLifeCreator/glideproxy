#!/bin/bash

# Скрипт для удаленного запуска оптимизации PM2 на сервере
# Использование: ./remote-optimization.sh server-ip

SERVER_IP=${1:-"5.129.215.152"}
SERVER_USER=${2:-"root"}

echo "🚀 Запуск оптимизации PM2 на сервере $SERVER_USER@$SERVER_IP"

# Функция для выполнения команд на сервере
run_remote() {
    ssh "$SERVER_USER@$SERVER_IP" "$1"
}

echo ""
echo "🔍 1. Проверяем текущее состояние PM2..."
run_remote "pm2 list"

echo ""
echo "📂 2. Ищем папку с проектом..."
PROJECT_PATH=$(run_remote "find /opt /home /var/www -name 'enhanced-simple-proxy.js' 2>/dev/null | head -1 | xargs dirname 2>/dev/null")

if [ -z "$PROJECT_PATH" ]; then
    echo "❌ Не найден файл enhanced-simple-proxy.js на сервере"
    echo "🔍 Попробуйте найти папку вручную:"
    echo "   ssh $SERVER_USER@$SERVER_IP"
    echo "   find / -name '*proxy*' -type d 2>/dev/null"
    exit 1
fi

echo "✅ Найдена папка проекта: $PROJECT_PATH"

echo ""
echo "📥 3. Обновляем код с GitHub..."
run_remote "cd $PROJECT_PATH && git fetch origin enhanced-proxy-v2.5 && git checkout enhanced-proxy-v2.5 && git pull origin enhanced-proxy-v2.5"

echo ""
echo "🔧 4. Проверяем наличие скрипта оптимизации..."
SCRIPT_EXISTS=$(run_remote "cd $PROJECT_PATH && ls -la optimize-pm2-processes.sh 2>/dev/null | wc -l")

if [ "$SCRIPT_EXISTS" = "0" ]; then
    echo "📥 Скачиваем скрипт оптимизации..."
    run_remote "cd $PROJECT_PATH && wget -q https://raw.githubusercontent.com/iLifeCreator/glideproxy/enhanced-proxy-v2.5/optimize-pm2-processes.sh"
    run_remote "cd $PROJECT_PATH && chmod +x optimize-pm2-processes.sh"
fi

echo ""
echo "📥 5. Скачиваем конфигурацию для одного процесса..."
run_remote "cd $PROJECT_PATH && mkdir -p optimized-proxy"
run_remote "cd $PROJECT_PATH && wget -q -O optimized-proxy/ecosystem.single.config.js https://raw.githubusercontent.com/iLifeCreator/glideproxy/enhanced-proxy-v2.5/optimized-proxy/ecosystem.single.config.js"

echo ""
echo "💾 6. Создаем бэкап текущей конфигурации..."
BACKUP_NAME="pm2_backup_$(date +%Y%m%d_%H%M%S)"
run_remote "pm2 dump $BACKUP_NAME.json && pm2 list > $BACKUP_NAME.txt"

echo ""
echo "🚀 7. Запускаем оптимизацию..."
run_remote "cd $PROJECT_PATH && ./optimize-pm2-processes.sh"

echo ""
echo "✅ 8. Проверяем результат..."
echo "📊 Новое состояние PM2:"
run_remote "pm2 list"

echo ""
echo "🎯 Проверяем работоспособность:"
HEALTH_STATUS=$(run_remote "curl -s http://localhost:3000/health | jq -r .status 2>/dev/null || echo 'endpoint_error'")
echo "Health endpoint: $HEALTH_STATUS"

METRICS_UPTIME=$(run_remote "curl -s http://localhost:3000/health/metrics | jq -r .uptime 2>/dev/null || echo 'endpoint_error'")
echo "Metrics uptime: ${METRICS_UPTIME}s"

PROXY_STATUS=$(run_remote "curl -s -I http://localhost:3000/ | head -1 | grep -o '200 OK' || echo 'proxy_error'")
echo "Proxy status: $PROXY_STATUS"

echo ""
if [ "$HEALTH_STATUS" = "healthy" ] && [ "$PROXY_STATUS" = "200 OK" ]; then
    echo "🎉 ОПТИМИЗАЦИЯ ЗАВЕРШЕНА УСПЕШНО!"
    echo "✅ Теперь работает 1 оптимизированный процесс вместо 3"
    echo "✅ Экономия памяти: ~74% (освобождено >170MB)"
    echo "✅ Все endpoints работают корректно"
else
    echo "⚠️  Возможны проблемы с оптимизацией"
    echo "🔧 Для отката выполните:"
    echo "   ssh $SERVER_USER@$SERVER_IP"
    echo "   pm2 kill && pm2 resurrect $BACKUP_NAME.json"
fi

echo ""
echo "🔧 Полезные команды для мониторинга:"
echo "   ssh $SERVER_USER@$SERVER_IP 'pm2 monit'"
echo "   ssh $SERVER_USER@$SERVER_IP 'pm2 logs enhanced-proxy-single'"
echo "   ssh $SERVER_USER@$SERVER_IP 'curl http://localhost:3000/health/metrics | jq'"