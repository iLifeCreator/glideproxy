#!/bin/bash

# Автоматический деплой Enhanced GlideApps Proxy v2.5 
# Целевой сервер: 5.129.215.152 (2 ядра / 4ГБ ОЗУ)

set -e

SERVER_IP="5.129.215.152"
echo "🚀 Запускаем автоматический деплой Enhanced Proxy на сервер $SERVER_IP"

# Скачивание и выполнение деплой скрипта
curl -fsSL https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/optimized-proxy/scripts/production-deploy.sh | SERVER_IP=$SERVER_IP bash

echo "✅ Деплой завершен!"
echo "🔗 Health check: http://$SERVER_IP:3000/health"
echo "📊 Metrics: http://$SERVER_IP:3000/health/metrics"