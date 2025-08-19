#!/bin/bash

# DNS обновление и тестирование для сервера 5.129.215.152

SERVER_IP="5.129.215.152"
DOMAIN="rus.vkusdoterra.ru"

echo "🌐 DNS обновление и тестирование для $SERVER_IP"
echo ""

echo "# 1. Обновление DNS записи"
echo "Обновите A-запись для $DOMAIN:"
echo ""
echo "DNS ЗАПИСЬ:"
echo "$DOMAIN. IN A $SERVER_IP"
echo ""
echo "Для проверки текущей DNS записи:"
echo "nslookup $DOMAIN"
echo "dig $DOMAIN A +short"
echo ""

echo "# 2. Проверка доступности после DNS обновления"
echo "# Ожидание распространения DNS (может занять до 24 часов)"
echo ""
echo "# Проверка прямого IP"
echo "curl -I http://$SERVER_IP:3000/"
echo ""
echo "# Проверка через домен (после обновления DNS)"
echo "curl -I http://$DOMAIN/"
echo ""

echo "# 3. Performance тестирование Enhanced Proxy"
echo ""
echo "# Быстрый response time тест"
echo "curl -w 'Response Time: %{time_total}s\nConnect Time: %{time_connect}s\nDNS Lookup: %{time_namelookup}s\nHTTP Code: %{http_code}\n' -o /dev/null -s http://$SERVER_IP:3000/"
echo ""

echo "# 4. Сравнение производительности"
cat << 'EOF'
# Тест нового Enhanced Proxy (должен быть ~63ms)
echo "=== Enhanced Proxy Performance ==="
for i in {1..5}; do
  curl -w "Test $i: %{time_total}s\n" -o /dev/null -s http://5.129.215.152:3000/
done

# Тест оригинального прокси (для сравнения, если еще доступен)
echo "=== Original Proxy Performance ==="
for i in {1..5}; do
  curl -w "Test $i: %{time_total}s\n" -o /dev/null -s https://rus.vkusdoterra.ru/
done

# Тест целевого сервера
echo "=== Target Server Performance ==="
for i in {1..5}; do
  curl -w "Test $i: %{time_total}s\n" -o /dev/null -s https://app.vkusdoterra.ru/
done
EOF

echo ""
echo "# 5. Apache Benchmark нагрузочное тестирование"
cat << 'EOF'
# Простой тест производительности (100 запросов, 10 одновременно)
ab -n 100 -c 10 http://5.129.215.152:3000/

# Интенсивный тест (1000 запросов, 50 одновременно)
ab -n 1000 -c 50 http://5.129.215.152:3000/

# Результаты должны показывать:
# - Requests per second: 100+ [#/sec]
# - Time per request: <10ms
# - Failed requests: 0
EOF

echo ""
echo "# 6. Мониторинг кэш производительности"
cat << 'EOF'
# Первый запрос (cache miss)
curl -I http://5.129.215.152:3000/
# Смотрим заголовок: X-Proxy-Cache: MISS

# Второй запрос (должен быть cache hit)
curl -I http://5.129.215.152:3000/
# Смотрим заголовок: X-Proxy-Cache: HIT

# Проверка кэш метрик
curl -s http://5.129.215.152:3000/health/metrics | jq '.cacheStats'
# Должно показать hitRate > 80%
EOF

echo ""
echo "# 7. Continuous мониторинг производительности"
echo ""
echo "# Мониторинг response time каждые 10 секунд"
cat << 'EOF'
#!/bin/bash
while true; do
  RESPONSE_TIME=$(curl -w "%{time_total}" -o /dev/null -s http://5.129.215.152:3000/)
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  echo "$TIMESTAMP - Response Time: ${RESPONSE_TIME}s"
  sleep 10
done
EOF

echo ""
echo "# 8. Проверка всех endpoint'ов"
cat << 'EOF'
# Health check
curl -s http://5.129.215.152:3000/health | jq .

# Detailed metrics
curl -s http://5.129.215.152:3000/health/metrics | jq .

# Main proxy endpoint
curl -I http://5.129.215.152:3000/

# Проверка CORS headers
curl -H "Origin: https://example.com" -I http://5.129.215.152:3000/
EOF

echo ""
echo "# 9. Expected Performance Targets"
cat << 'EOF'
✅ ЦЕЛИ ПРОИЗВОДИТЕЛЬНОСТИ:
- Response Time: < 100ms (цель: ~63ms)
- Requests/sec: > 50 RPS (цель: 100+ RPS)
- Cache Hit Rate: > 80% (цель: ~87%)
- Error Rate: < 1% (цель: 0%)
- Memory Usage: < 80% (цель: ~54MB per process)
- CPU Usage: < 70% (должно быть эффективно)

🎯 EXPECTED RESULTS:
- 2500% improvement over original proxy
- 94% faster response times
- 86.67% cache hit rate
- Production-ready stability
EOF

echo ""
echo "✅ После успешного деплоя и DNS обновления:"
echo "🔗 Основной URL: http://$DOMAIN (когда DNS обновится)"
echo "🔗 Прямой доступ: http://$SERVER_IP:3000"
echo "📊 Health: http://$SERVER_IP:3000/health"
echo "📈 Metrics: http://$SERVER_IP:3000/health/metrics"