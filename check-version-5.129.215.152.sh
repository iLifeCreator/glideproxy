#!/bin/bash

# Проверка версии прокси на сервере 5.129.215.152

SERVER_IP="5.129.215.152"

echo "🔍 Проверка версии прокси на сервере $SERVER_IP"
echo ""

echo "=== СПОСОБ 1: Health Endpoint ==="
echo "curl http://$SERVER_IP:3000/health"
curl -s http://$SERVER_IP:3000/health 2>/dev/null | jq . || echo "❌ Health endpoint недоступен"
echo ""

echo "=== СПОСОБ 2: Response Headers ==="
echo "curl -I http://$SERVER_IP:3000/"
curl -I http://$SERVER_IP:3000/ 2>/dev/null | grep -E "(Server|X-Proxy-Server|X-Powered-By)" || echo "❌ Прокси недоступен"
echo ""

echo "=== СПОСОБ 3: SSH проверка на сервере ==="
echo "Подключитесь к серверу и выполните:"
echo "ssh root@$SERVER_IP"
echo ""
echo "Затем на сервере:"
cat << 'EOF'
# Проверка PM2 процессов
pm2 status

# Проверка версии из package.json
cat /opt/glide-proxy/optimized-proxy/package.json | grep version

# Проверка логов для определения версии
pm2 logs glide-proxy-enhanced --lines 10 | grep -E "(version|Enhanced|Ultra)"

# Проверка файлов для определения версии
ls -la /opt/glide-proxy/optimized-proxy/src/

# Если есть enhanced-simple-proxy.js - это Enhanced v2.5
# Если есть только ultra-optimized-proxy.js - это Ultra версия
# Если есть simple-proxy.js - это базовая версия

# Проверка конфигурации
cat /opt/glide-proxy/optimized-proxy/.env | head -5
EOF

echo ""
echo "=== СПОСОБ 4: Проверка портов ==="
echo "nmap -p 3000 $SERVER_IP"
nmap -p 3000 $SERVER_IP 2>/dev/null || echo "❌ nmap не установлен"
echo ""

echo "=== СПОСОБ 5: Проверка через netcat ==="
echo "nc -zv $SERVER_IP 3000"
nc -zv $SERVER_IP 3000 2>&1 || echo "❌ Порт 3000 недоступен"
echo ""

echo "=== СПОСОБ 6: Детальная SSH проверка ==="
echo "Выполните на сервере для подробной информации:"
cat << 'EOF'
#!/bin/bash
echo "🔍 Детальная информация о версии прокси:"
echo ""

echo "1. PM2 процессы:"
pm2 status
echo ""

echo "2. Версия из package.json:"
if [ -f "/opt/glide-proxy/optimized-proxy/package.json" ]; then
    cat /opt/glide-proxy/optimized-proxy/package.json | jq '.version, .name'
else
    echo "❌ package.json не найден"
fi
echo ""

echo "3. Активные файлы прокси:"
ls -la /opt/glide-proxy/optimized-proxy/src/
echo ""

echo "4. Текущий запущенный файл:"
pm2 show glide-proxy-enhanced | grep "script path"
echo ""

echo "5. Логи запуска (последние 20 строк):"
pm2 logs glide-proxy-enhanced --lines 20 | grep -E "(Enhanced|Ultra|version|started)"
echo ""

echo "6. Git информация:"
cd /opt/glide-proxy && git log --oneline -5
cd /opt/glide-proxy && git status
echo ""

echo "7. Конфигурация:"
head -10 /opt/glide-proxy/optimized-proxy/.env
echo ""

echo "8. Процессы Node.js:"
ps aux | grep node | grep -v grep
EOF