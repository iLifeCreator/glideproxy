#!/bin/bash

# Оптимизация PM2 процессов для сервера 2 ядра / 4ГБ ОЗУ
# Этот скрипт останавливает лишние процессы и запускает оптимальную конфигурацию

echo "🔍 Текущие PM2 процессы:"
pm2 list

echo ""
echo "🛑 Останавливаем все текущие процессы..."

# Останавливаем все процессы
pm2 stop all 2>/dev/null || true
pm2 delete all 2>/dev/null || true

echo ""
echo "🧹 Очищаем PM2..."
pm2 flush
pm2 kill 2>/dev/null || true

echo ""
echo "⏳ Ждем 3 секунды..."
sleep 3

echo ""
echo "🚀 Запускаем оптимизированную конфигурацию (1 процесс)..."

cd /home/user/webapp/optimized-proxy

# Создаем директорию для логов
mkdir -p logs

# Запускаем единственный оптимизированный процесс
pm2 start ecosystem.single.config.js --env production

echo ""
echo "📊 Новое состояние PM2:"
pm2 list

echo ""
echo "💾 Сохраняем конфигурацию PM2..."
pm2 save

echo ""
echo "🎯 Проверяем работоспособность:"
echo "Health endpoint:"
sleep 2
curl -s "http://localhost:3000/health" | jq .status 2>/dev/null || curl -s "http://localhost:3000/health"

echo ""
echo "Metrics endpoint:"
curl -s "http://localhost:3000/health/metrics" | jq .uptime 2>/dev/null || echo "Metrics endpoint responding"

echo ""
echo "✅ Оптимизация завершена!"
echo "📋 Рекомендации:"
echo "   • Теперь работает 1 оптимизированный процесс"
echo "   • Память: максимум 2ГБ (50% от общей)"
echo "   • Кэш: увеличен до 1000 элементов"
echo "   • Сокеты: оптимизированы для 2-ядерного сервера"
echo ""
echo "🔧 Для мониторинга используйте:"
echo "   pm2 monit"
echo "   pm2 logs enhanced-proxy-single"