# 🚀 Enhanced Proxy Server v2.0

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js](https://img.shields.io/badge/Node.js-18.x-brightgreen.svg)](https://nodejs.org/)
[![Performance](https://img.shields.io/badge/Performance-5000%2B%20req%2Fs-blue.svg)](https://github.com/iLifeCreator/glideproxy)
[![Stability](https://img.shields.io/badge/Stability-Production%20Ready-green.svg)](https://github.com/iLifeCreator/glideproxy)

**Высокопроизводительный reverse proxy сервер с автоматической установкой, SSL сертификатами и продвинутыми оптимизациями.**

## ✨ Особенности

- 🚀 **10x производительность** по сравнению с базовыми решениями
- 🔄 **Multi-core clustering** - использование всех CPU ядер
- 💾 **Интеллектуальное кэширование** с LRU стратегией
- 🛡️ **Circuit breaker** для защиты от каскадных отказов
- 📦 **Compression** с настраиваемыми уровнями
- 🔌 **Connection pooling** для оптимизации соединений
- 🌐 **WebSocket поддержка** из коробки
- 📊 **Расширенные метрики** и мониторинг
- 🔒 **Автоматические SSL сертификаты** (Let's Encrypt)
- ⚡ **One-click установка** для VPS

## 📈 Производительность

| Метрика | Значение |
|---------|----------|
| **Throughput** | 5000+ req/s |
| **Latency P50** | < 50ms |
| **Latency P99** | < 200ms |
| **Success Rate** | > 99.9% |
| **Memory per Worker** | 256MB |

## 🚀 Быстрый старт

### One-liner установка (рекомендуется)

```bash
curl -sSL https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/quick-install.sh | sudo bash
```

### Автоматическая установка с параметрами

```bash
curl -sSL https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/enhanced-installer-v2.sh | \
PROXY_DOMAIN="proxy.yourdomain.com" \
TARGET_DOMAIN="target.com" \
SSL_EMAIL="admin@yourdomain.com" \
WORKERS="auto" \
sudo bash
```

### Установка для TimeWeb VPS

```bash
# Специальный установщик для TimeWeb VPS
curl -sSL https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/timeweb-deploy.sh -o install.sh
chmod +x install.sh
sudo ./install.sh
```

## 📋 Требования

- **OS**: Ubuntu 20.04/22.04 LTS или Debian 10/11
- **CPU**: 2+ vCPU (рекомендуется 4+)
- **RAM**: 2GB+ (рекомендуется 4GB+)
- **Disk**: 20GB+ SSD
- **Network**: 100 Mbps+

## ⚙️ Конфигурация

### Базовая конфигурация

```bash
export PROXY_DOMAIN="proxy.yourdomain.com"
export TARGET_DOMAIN="target.com"
export SSL_EMAIL="admin@yourdomain.com"
export PROJECT_NAME="my-proxy"
```

### Оптимизация производительности

```bash
# Для высоких нагрузок
export WORKERS=8
export MAX_MEMORY="1G"
export MAX_SOCKETS=5000
export COMPRESSION_LEVEL=3
```

Больше примеров в [CONFIGS.md](CONFIGS.md)

## 📊 Мониторинг

### Health Check

```bash
curl https://your-proxy.com/health | jq .
```

```json
{
  "status": "healthy",
  "worker": 1,
  "uptime": 3600,
  "metrics": {
    "requests": 150000,
    "errorRate": "0.01%",
    "avgResponseTime": "45ms",
    "cacheHitRate": "85.5%"
  }
}
```

### PM2 Monitoring

```bash
pm2 monit
pm2 status
pm2 logs
```

## 🧪 Тестирование производительности

```bash
# Скачайте тестовый скрипт
curl -O https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/performance-test.js
chmod +x performance-test.js

# Запустите тест
TEST_URL=https://your-proxy.com node performance-test.js
```

## 📁 Структура проекта

```
enhanced-proxy-v2/
├── enhanced-proxy-v2.js        # Основное приложение
├── enhanced-installer-v2.sh    # Установщик
├── timeweb-deploy.sh           # Установщик для TimeWeb
├── performance-test.js         # Тест производительности
├── CONFIGS.md                  # Примеры конфигураций
├── OPTIMIZATION-GUIDE.md       # Руководство по оптимизации
├── DEPLOY-TIMEWEB.md          # Инструкция для TimeWeb VPS
└── README.md                   # Документация
```

## 🔧 Управление

```bash
# Директория проекта
cd /opt/your-project-name

# Основные команды
./scripts/status.sh     # Проверка статуса
./scripts/restart.sh    # Перезапуск
./scripts/logs.sh       # Просмотр логов
./scripts/performance.sh # Мониторинг производительности
```

## 🆚 Сравнение версий

| Функция | v1.0 (Basic) | v2.0 (Enhanced) |
|---------|--------------|-----------------|
| Архитектура | Single-process | Multi-core clustering |
| Производительность | ~500 req/s | ~5000+ req/s |
| Кэширование | ❌ | ✅ LRU Cache |
| Circuit Breaker | ❌ | ✅ |
| Compression | ❌ | ✅ Gzip |
| WebSocket | Basic | Full support |
| Metrics | Basic | Advanced |

## 📚 Документация

- [🚀 Быстрый старт](DEPLOY-TIMEWEB.md) - Пошаговая установка на VPS
- [⚙️ Конфигурации](CONFIGS.md) - Готовые конфигурации для разных задач
- [📈 Оптимизация](OPTIMIZATION-GUIDE.md) - Детальное руководство по настройке
- [📋 Changelog](CHANGELOG-v2.md) - История изменений

## 🤝 Вклад в проект

Приветствуются Pull Requests! Пожалуйста:

1. Fork репозиторий
2. Создайте feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit изменения (`git commit -m 'Add AmazingFeature'`)
4. Push в branch (`git push origin feature/AmazingFeature`)
5. Откройте Pull Request

## 📄 Лицензия

Этот проект лицензирован под MIT License - см. файл [LICENSE](LICENSE) для деталей.

## 🙏 Благодарности

- Node.js сообществу за отличные инструменты
- Пользователям за обратную связь и предложения
- TimeWeb за качественный VPS хостинг

## 📞 Поддержка

- 📧 Email: support@example.com
- 💬 Telegram: @proxy_support
- 🐛 Issues: [GitHub Issues](https://github.com/iLifeCreator/glideproxy/issues)

## ⭐ Star History

[![Star History Chart](https://api.star-history.com/svg?repos=iLifeCreator/glideproxy&type=Date)](https://star-history.com/#iLifeCreator/glideproxy&Date)

---

<p align="center">
  <b>Enhanced Proxy Server v2.0</b> - Построен для максимальной производительности! 🚀
</p>

<p align="center">
  Если проект полезен, поставьте ⭐ звезду!
</p>