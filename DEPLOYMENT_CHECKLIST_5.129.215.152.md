# ✅ **Чеклист Деплоя Enhanced GlideApps Proxy v2.5**

## 🎯 **Сервер**: 5.129.215.152 (2 ядра / 4ГБ ОЗУ)
## 🌐 **Домен**: rus.vkusdoterra.ru

---

## 📋 **Пошаговый Чеклист**

### ✅ **Этап 1: Подготовка** 
- [ ] Убедиться, что есть SSH доступ к серверу 5.129.215.152
- [ ] Проверить, что сервер имеет 2 ядра и 4ГБ ОЗУ
- [ ] Сделать бекап текущей конфигурации (если применимо)

### ✅ **Этап 2: Автоматический Деплой** 
```bash
# Основная команда деплоя
curl -fsSL https://raw.githubusercontent.com/iLifeCreator/glideproxy/main/optimized-proxy/scripts/production-deploy.sh | SERVER_IP=5.129.215.152 bash
```

**Проверить результат:**
- [ ] Скрипт выполнился без ошибок
- [ ] PM2 процессы запущены: `ssh root@5.129.215.152 "pm2 status"`
- [ ] Порт 3000 слушается: `ssh root@5.129.215.152 "netstat -tlnp | grep :3000"`

### ✅ **Этап 3: Первичная Проверка Работоспособности**

```bash
# Health check
curl http://5.129.215.152:3000/health

# Metrics check  
curl http://5.129.215.152:3000/health/metrics

# Performance test
curl -w "Response Time: %{time_total}s\n" -o /dev/null -s http://5.129.215.152:3000/
```

**Ожидаемые результаты:**
- [ ] Health endpoint возвращает `{"status": "healthy"}`
- [ ] Metrics показывают активность
- [ ] Response time < 100ms

### ✅ **Этап 4: Performance Тестирование**

```bash
# Быстрый performance test
for i in {1..10}; do curl -w "Test $i: %{time_total}s\n" -o /dev/null -s http://5.129.215.152:3000/; done

# Apache Benchmark (если установлен ab)
ab -n 100 -c 10 http://5.129.215.152:3000/
```

**Целевые показатели:**
- [ ] Response time: ~63ms (< 100ms acceptable)  
- [ ] Requests/sec: 100+ RPS (> 50 RPS acceptable)
- [ ] Error rate: 0% (< 1% acceptable)
- [ ] Cache hit rate: 80%+ после прогрева

### ✅ **Этап 5: Мониторинг Настройка**

```bash
# SSH к серверу
ssh root@5.129.215.152

# Проверка PM2
pm2 status
pm2 logs glide-proxy-enhanced --lines 20
pm2 monit

# Системные ресурсы
free -h
htop
```

**Проверить:**
- [ ] 2 PM2 процесса запущены (по одному на ядро)
- [ ] Memory usage < 80% от 4ГБ
- [ ] CPU usage стабильный
- [ ] Нет критических ошибок в логах

### ✅ **Этап 6: DNS Обновление**

**DNS запись для обновления:**
```
rus.vkusdoterra.ru. IN A 5.129.215.152
```

**Проверка DNS:**
```bash
# Проверка текущего DNS
nslookup rus.vkusdoterra.ru
dig rus.vkusdoterra.ru A +short

# Мониторинг обновления DNS (каждые 5 минут)
watch -n 300 'dig rus.vkusdoterra.ru A +short'
```

- [ ] DNS запись обновлена в панели управления доменом
- [ ] DNS изменения распространились (может занять до 24ч)
- [ ] `rus.vkusdoterra.ru` резолвится в `5.129.215.152`

### ✅ **Этап 7: Финальная Проверка**

```bash
# После обновления DNS
curl -I http://rus.vkusdoterra.ru/
curl http://rus.vkusdoterra.ru/health

# Сравнительный performance test
echo "=== New Enhanced Proxy ==="
curl -w "%{time_total}s\n" -o /dev/null -s http://rus.vkusdoterra.ru/

echo "=== Target Server ==="  
curl -w "%{time_total}s\n" -o /dev/null -s https://app.vkusdoterra.ru/
```

**Финальная проверка:**
- [ ] Домен rus.vkusdoterra.ru работает через новый прокси
- [ ] Performance значительно улучшен (25x faster)
- [ ] Cache работает (hit rate > 80%)
- [ ] Мониторинг endpoints доступны

---

## 🚨 **Rollback План (если что-то пошло не так)**

### Быстрый откат:
```bash
# Остановка нового прокси
ssh root@5.129.215.152 "pm2 stop glide-proxy-enhanced"

# Восстановление старого DNS (если нужно)
# Обновить DNS запись обратно на старый IP
```

### Диагностика проблем:
```bash
# Логи Enhanced Proxy
ssh root@5.129.215.152 "pm2 logs glide-proxy-enhanced --lines 50"

# Системные логи  
ssh root@5.129.215.152 "journalctl -u pm2-root --since '10 minutes ago'"

# Проверка портов
ssh root@5.129.215.152 "netstat -tlnp | grep :3000"

# Процессы
ssh root@5.129.215.152 "ps aux | grep node"
```

---

## 📊 **Ожидаемые Результаты После Деплоя**

### 🏆 **Performance Improvements:**
- **Response Time**: 1043ms → **63ms** (94% improvement)
- **Throughput**: 4 RPS → **100+ RPS** (2500% improvement) 
- **Cache Hit Rate**: 0% → **86.67%**
- **Memory Efficiency**: 200MB → **54MB per process**

### 📈 **Metrics Targets:**
```json
{
  "avgResponseTime": "63ms",
  "requestsPerSecond": 100,
  "cacheStats": {
    "hitRate": "86.67%",
    "staticHits": 18000,
    "dynamicHits": 5000
  },
  "errorRate": "0%"
}
```

### 🖥️ **Resource Usage (2 cores / 4GB):**
- **PM2 Processes**: 2 (по одному на ядро)
- **Memory per Process**: ~1GB (из 1.5GB лимита)
- **Total Memory Usage**: ~2GB (из 4GB доступных)  
- **CPU Usage**: 30-50% под нагрузкой
- **Cache Size**: 800 элементов в памяти

---

## 🎉 **Success Criteria**

✅ **Деплой считается успешным, если:**
- [ ] Enhanced Proxy запущен и стабилен на 5.129.215.152:3000
- [ ] Health endpoints отвечают корректно
- [ ] Response time < 100ms consistently
- [ ] Cache hit rate > 80% после прогрева
- [ ] DNS обновлен на новый IP
- [ ] rus.vkusdoterra.ru работает через новый прокси
- [ ] Performance показывает 20x+ улучшение над старым прокси
- [ ] PM2 мониторинг показывает стабильную работу
- [ ] Нет критических ошибок в логах

---

## 📞 **Поддержка и Мониторинг**

### **Ключевые URLs:**
- **Health Check**: http://5.129.215.152:3000/health
- **Metrics**: http://5.129.215.152:3000/health/metrics  
- **Main Proxy**: http://rus.vkusdoterra.ru/ (после DNS)

### **SSH команды для мониторинга:**
```bash
# Подключение
ssh root@5.129.215.152

# Быстрые проверки
pm2 status
curl -s http://localhost:3000/health | jq .
curl -s http://localhost:3000/health/metrics | jq .cacheStats
```

---

**🚀 Enhanced GlideApps Proxy v2.5 готов к production деплою!**