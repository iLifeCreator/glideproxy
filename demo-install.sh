#!/bin/bash

# Демонстрационный скрипт для Universal Reverse Proxy Installer
# Показывает различные способы использования

echo "=== UNIVERSAL REVERSE PROXY INSTALLER - DEMO ==="
echo
echo "Этот скрипт демонстрирует различные способы использования установщика"
echo

# Проверка наличия установщика
if [ ! -f "universal-proxy-installer.sh" ]; then
    echo "❌ Файл universal-proxy-installer.sh не найден"
    echo "Скачайте его с помощью:"
    echo "curl -O https://your-server.com/universal-proxy-installer.sh"
    exit 1
fi

echo "✅ Установщик найден"
echo

# Демонстрация синтаксиса
echo "=== СПОСОБЫ ИСПОЛЬЗОВАНИЯ ==="
echo

echo "1. Интерактивный режим:"
echo "   sudo ./universal-proxy-installer.sh"
echo

echo "2. Автоматический режим (переменные окружения):"
echo "   export PROXY_DOMAIN=\"proxy.example.com\""
echo "   export TARGET_DOMAIN=\"old.example.com\""
echo "   export SSL_EMAIL=\"admin@example.com\""
echo "   export PROJECT_NAME=\"my-proxy\""
echo "   sudo ./universal-proxy-installer.sh"
echo

echo "3. One-liner установка:"
echo "   curl -sSL https://server.com/universal-proxy-installer.sh | \\"
echo "   PROXY_DOMAIN=\"proxy.example.com\" \\"
echo "   TARGET_DOMAIN=\"old.example.com\" \\"
echo "   SSL_EMAIL=\"admin@example.com\" \\"
echo "   sudo bash"
echo

echo "=== ПРИМЕРЫ КОНФИГУРАЦИЙ ==="
echo

echo "📝 Пример 1: Простой reverse proxy"
cat << 'EOF'
export PROXY_DOMAIN="proxy.mysite.com"
export TARGET_DOMAIN="old.mysite.com"
export SSL_EMAIL="webmaster@mysite.com"
export PROJECT_NAME="mysite-proxy"
sudo ./universal-proxy-installer.sh
EOF
echo

echo "📝 Пример 2: High-performance API proxy"
cat << 'EOF'
export PROXY_DOMAIN="api-proxy.company.com"
export TARGET_DOMAIN="legacy-api.company.com"
export SSL_EMAIL="devops@company.com"
export PROJECT_NAME="api-proxy"
export NODE_PORT="8080"
export MAX_MEMORY="1G"
export RATE_LIMIT="50"
sudo ./universal-proxy-installer.sh
EOF
echo

echo "📝 Пример 3: HTTPS proxy для HTTP backend"
cat << 'EOF'
export PROXY_DOMAIN="secure.example.com"
export TARGET_DOMAIN="internal.example.com"
export TARGET_PROTOCOL="http"
export SSL_EMAIL="security@example.com"
export PROJECT_NAME="secure-proxy"
sudo ./universal-proxy-installer.sh
EOF
echo

echo "=== ПРОВЕРКА ГОТОВНОСТИ СИСТЕМЫ ==="
echo

# Проверка ОС
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "✅ ОС: $PRETTY_NAME"
    
    case "$ID" in
        ubuntu)
            if [[ $(echo "$VERSION_ID >= 18.04" | bc) -eq 1 ]]; then
                echo "✅ Версия Ubuntu поддерживается"
            else
                echo "⚠️  Рекомендуется Ubuntu 18.04+"
            fi
            ;;
        debian)
            if [[ $(echo "$VERSION_ID >= 10" | bc) -eq 1 ]]; then
                echo "✅ Версия Debian поддерживается"
            else
                echo "⚠️  Рекомендуется Debian 10+"
            fi
            ;;
        *)
            echo "⚠️  ОС может не поддерживаться (рекомендуется Ubuntu/Debian)"
            ;;
    esac
else
    echo "❓ Не удалось определить ОС"
fi

# Проверка прав root
if [[ $EUID -eq 0 ]]; then
    echo "✅ Запущено с правами root"
else
    echo "❌ Требуются права root (используйте sudo)"
fi

# Проверка памяти
MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEMORY_MB=$((MEMORY_KB / 1024))
echo "💾 Доступная память: ${MEMORY_MB}MB"
if [ $MEMORY_MB -ge 1024 ]; then
    echo "✅ Памяти достаточно"
elif [ $MEMORY_MB -ge 512 ]; then
    echo "⚠️  Памяти минимально достаточно (рекомендуется 1GB+)"
else
    echo "❌ Недостаточно памяти (требуется минимум 512MB)"
fi

# Проверка свободного места
DISK_AVAILABLE=$(df / | tail -1 | awk '{print $4}')
DISK_AVAILABLE_GB=$((DISK_AVAILABLE / 1024 / 1024))
echo "💽 Свободное место: ${DISK_AVAILABLE_GB}GB"
if [ $DISK_AVAILABLE_GB -ge 2 ]; then
    echo "✅ Места на диске достаточно"
else
    echo "❌ Недостаточно места на диске (требуется минимум 2GB)"
fi

# Проверка интернет соединения
echo "🌐 Проверка интернет соединения..."
if ping -c 1 google.com &> /dev/null; then
    echo "✅ Интернет соединение работает"
else
    echo "❌ Нет интернет соединения"
fi

echo
echo "=== СЛЕДУЮЩИЕ ШАГИ ==="
echo

echo "1. Убедитесь, что DNS записи для вашего домена указывают на этот сервер"
echo "2. Подготовьте следующие данные:"
echo "   - Домен прокси (например: proxy.example.com)"
echo "   - Целевой домен (например: old.example.com)"  
echo "   - Email для SSL сертификата"
echo "3. Запустите установку одним из способов выше"
echo

echo "=== ДОПОЛНИТЕЛЬНАЯ ИНФОРМАЦИЯ ==="
echo
echo "📚 Документация:"
echo "   - README.md - Быстрый старт"
echo "   - USAGE.md - Подробная инструкция"
echo "   - memory_bank/tasks.md - Технические детали"
echo
echo "🔗 После установки будут доступны endpoints:"
echo "   - https://your-domain.com/ (основной прокси)"
echo "   - https://your-domain.com/health (health check)"
echo "   - https://your-domain.com/nginx-health (nginx status)"
echo
echo "🛠️ Управление проектом:"
echo "   cd /opt/your-project-name"
echo "   ./scripts/status.sh    # статус"
echo "   ./scripts/restart.sh   # перезапуск"
echo "   ./scripts/logs.sh      # логи"
echo

echo "✨ Готово! Теперь вы можете запустить установку." 