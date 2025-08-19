#!/bin/bash

# Команды для мониторинга Enhanced Proxy на сервере 5.129.215.152

SERVER_IP="5.129.215.152"

echo "📊 Команды для мониторинга сервера $SERVER_IP"
echo ""

echo "# Проверка Health Endpoints"
echo "curl http://$SERVER_IP:3000/health"
echo "curl http://$SERVER_IP:3000/health/metrics | jq ."
echo ""

echo "# SSH подключение к серверу"
echo "ssh root@$SERVER_IP"
echo ""

echo "# PM2 управление (выполнять на сервере)"
cat << 'EOF'
# Статус всех процессов
sudo pm2 status

# Логи Enhanced Proxy
sudo pm2 logs glide-proxy-enhanced

# Логи в реальном времени
sudo pm2 logs glide-proxy-enhanced --lines 0

# Перезапуск сервиса
sudo pm2 restart glide-proxy-enhanced

# Плавная перезагрузка (zero-downtime)
sudo pm2 reload glide-proxy-enhanced

# Остановка сервиса
sudo pm2 stop glide-proxy-enhanced

# Запуск сервиса
sudo pm2 start glide-proxy-enhanced

# Мониторинг ресурсов
sudo pm2 monit

# Информация о процессе
sudo pm2 show glide-proxy-enhanced
EOF

echo ""
echo "# Системный мониторинг (на сервере)"
cat << 'EOF'
# Использование ресурсов
htop

# Использование памяти
free -h

# Использование диска
df -h

# Сетевые соединения
sudo netstat -tlnp | grep :3000

# Активные соединения к прокси
sudo ss -tuln | grep :3000

# Процессы Node.js
ps aux | grep node
EOF

echo ""
echo "# Performance тестирование"
echo "# Быстрый тест производительности"
echo "curl -w 'Total: %{time_total}s, Connect: %{time_connect}s, Response: %{time_starttransfer}s\n' -o /dev/null -s http://$SERVER_IP:3000/"
echo ""
echo "# Apache Benchmark тест (если установлен ab)"
echo "ab -n 100 -c 10 http://$SERVER_IP:3000/"
echo ""

echo "# Continuous мониторинг метрик (каждые 5 секунд)"
echo "watch -n 5 'curl -s http://$SERVER_IP:3000/health/metrics | jq .'"
echo ""

echo "# Проверка логов системы"
cat << 'EOF'
# Системные логи
sudo journalctl -u pm2-root -f

# Nginx логи (если используется)
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Системные ресурсы
dstat -cdngy
EOF

echo ""
echo "✅ Полезные алиасы для ~/.bashrc на сервере:"
cat << 'EOF'
# Добавить в ~/.bashrc на сервере
alias pm2status='sudo pm2 status'
alias pm2logs='sudo pm2 logs glide-proxy-enhanced'
alias pm2restart='sudo pm2 restart glide-proxy-enhanced'
alias pm2reload='sudo pm2 reload glide-proxy-enhanced'
alias proxyhealth='curl -s http://localhost:3000/health | jq .'
alias proxymetrics='curl -s http://localhost:3000/health/metrics | jq .'
alias proxytop='sudo pm2 monit'
EOF