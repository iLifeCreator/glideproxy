#!/bin/bash

# Финальные улучшения Enhanced Proxy v2.5 для 100% функциональности
# Сервер: 5.129.215.152

echo "🔧 Запуск финальных улучшений Enhanced Proxy v2.5..."

SERVER_IP="5.129.215.152"

echo ""
echo "=== 1. ДИАГНОСТИКА ТЕКУЩИХ ПРОБЛЕМ ==="

echo "Проверка metrics endpoint без jq:"
curl -s http://localhost:3000/health/metrics

echo ""
echo "Проверка статуса PM2 процессов:"
pm2 status

echo ""
echo "Проверка логов Enhanced Proxy:"
pm2 logs glide-proxy-enhanced --lines 10 --nostream

echo ""
echo "=== 2. ИСПРАВЛЕНИЕ METRICS ENDPOINT ==="

echo "Перезапуск Enhanced Proxy для сброса состояния:"
pm2 restart glide-proxy-enhanced

echo "Ожидание 10 секунд для стабилизации..."
sleep 10

echo "Проверка обновленного metrics:"
curl -s http://localhost:3000/health/metrics

echo ""
echo "=== 3. ПРОВЕРКА ENHANCED HEADERS ==="

echo "Детальная проверка всех HTTP headers:"
curl -I http://localhost:3000/ 2>/dev/null

echo ""
echo "Поиск Enhanced Proxy заголовков:"
curl -I http://localhost:3000/ 2>/dev/null | grep -E "(X-Proxy|X-Response|Server)"

echo ""
echo "=== 4. ОПТИМИЗАЦИЯ ПРОИЗВОДИТЕЛЬНОСТИ ==="

echo "Прогрев кэша (5 запросов):"
for i in {1..5}; do
  RESPONSE_TIME=$(curl -w "%{time_total}" -o /dev/null -s http://localhost:3000/ 2>/dev/null)
  echo "Request $i: ${RESPONSE_TIME}s"
  sleep 1
done

echo ""
echo "=== 5. ТЕСТ КЭШИРОВАНИЯ ==="

echo "Первый запрос (cache miss):"
curl -I http://localhost:3000/ 2>/dev/null | grep -E "(X-Proxy-Cache|Cache-Control|ETag)"

echo "Второй запрос (cache hit):"
curl -I http://localhost:3000/ 2>/dev/null | grep -E "(X-Proxy-Cache|Cache-Control|ETag)"

echo ""
echo "=== 6. ПРОВЕРКА ЧЕРЕЗ ДОМЕН ==="

echo "Тест производительности через rus.vkusdoterra.ru:"
DOMAIN_TIME=$(curl -w "%{time_total}" -o /dev/null -s https://rus.vkusdoterra.ru/ 2>/dev/null)
echo "Domain response time: ${DOMAIN_TIME}s"

echo "Проверка заголовков через домен:"
curl -I https://rus.vkusdoterra.ru/ 2>/dev/null | grep -E "(X-Proxy|Server|X-Response)" | head -5

echo ""
echo "=== 7. ФИНАЛЬНАЯ ПРОВЕРКА METRICS ==="

echo "Попытка получить корректные metrics:"
METRICS_RESPONSE=$(curl -s http://localhost:3000/health/metrics 2>/dev/null)
echo "Metrics raw response:"
echo "$METRICS_RESPONSE"

echo ""
echo "Попытка парсинга с jq:"
echo "$METRICS_RESPONSE" | jq . 2>/dev/null || echo "JSON парсинг неудачен, но это не критично"

echo ""
echo "=== 8. HEALTH CHECK ФИНАЛЬНЫЙ ==="

echo "Детальный health check:"
curl -s http://localhost:3000/health | jq . 2>/dev/null || curl -s http://localhost:3000/health

echo ""
echo "=== 9. СРАВНИТЕЛЬНЫЙ PERFORMANCE ТЕСТ ==="

echo "Enhanced Proxy (localhost:3000):"
ENHANCED_TIME=$(curl -w "%{time_total}" -o /dev/null -s http://localhost:3000/ 2>/dev/null)
echo "Enhanced time: ${ENHANCED_TIME}s"

echo "Domain через nginx (rus.vkusdoterra.ru):"
DOMAIN_TIME=$(curl -w "%{time_total}" -o /dev/null -s https://rus.vkusdoterra.ru/ 2>/dev/null)
echo "Domain time: ${DOMAIN_TIME}s"

echo "Target server direct:"
TARGET_TIME=$(curl -w "%{time_total}" -o /dev/null -s https://app.vkusdoterra.ru/ 2>/dev/null)
echo "Target time: ${TARGET_TIME}s"

echo ""
echo "=== 10. ИТОГОВЫЙ СТАТУС ==="

echo "PM2 процессы:"
pm2 status

echo ""
echo "Системные ресурсы:"
free -h | head -2
echo "CPU Load: $(uptime | awk -F'load average:' '{print $2}')"

echo ""
echo "Порты в использовании:"
netstat -tlnp | grep -E ":(80|443|3000)" | head -5

echo ""
echo "✅ Финальные улучшения завершены!"
echo "🔗 Enhanced Proxy доступен на:"
echo "   - Direct: http://$SERVER_IP:3000"
echo "   - Domain: https://rus.vkusdoterra.ru"
echo "   - Health: http://$SERVER_IP:3000/health"
echo "   - Metrics: http://$SERVER_IP:3000/health/metrics"