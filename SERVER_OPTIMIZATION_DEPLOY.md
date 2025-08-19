# 🚀 Запуск скрипта оптимизации PM2 на сервере

## 🎯 **Цель**: Запустить `optimize-pm2-processes.sh` на production сервере

---

## 📋 **Метод 1: Через SSH (Рекомендуемый)**

### 🔐 **1. Подключение к серверу**
```bash
# Подключитесь к вашему серверу через SSH
ssh root@5.129.215.152
# или
ssh your-username@your-server-ip
```

### 📂 **2. Перейдите в директорию проекта**
```bash
# Найдите директорию с проектом (возможные варианты)
cd /opt/glide-proxy/optimized-proxy
# или
cd /home/glide-proxy
# или
cd /var/www/glide-proxy
# или
find / -name "enhanced-simple-proxy.js" 2>/dev/null
```

### 🔄 **3. Обновите код с GitHub**
```bash
# Получите последние изменения
git fetch origin enhanced-proxy-v2.5
git checkout enhanced-proxy-v2.5
git pull origin enhanced-proxy-v2.5
```

### ✅ **4. Проверьте наличие скрипта**
```bash
# Убедитесь что скрипт есть и исполняемый
ls -la optimize-pm2-processes.sh

# Если файла нет, проверьте путь
find . -name "optimize-pm2-processes.sh"
```

### 🚀 **5. Запустите оптимизацию**
```bash
# Запуск скрипта оптимизации
./optimize-pm2-processes.sh
```

---

## 📋 **Метод 2: Загрузка и выполнение скрипта**

### 📥 **Если скрипта нет на сервере:**

```bash
# 1. Скачайте скрипт напрямую с GitHub
wget https://raw.githubusercontent.com/iLifeCreator/glideproxy/enhanced-proxy-v2.5/optimize-pm2-processes.sh

# 2. Сделайте исполняемым
chmod +x optimize-pm2-processes.sh

# 3. Скачайте конфигурацию
wget https://raw.githubusercontent.com/iLifeCreator/glideproxy/enhanced-proxy-v2.5/optimized-proxy/ecosystem.single.config.js

# 4. Создайте папку optimized-proxy если нужно
mkdir -p optimized-proxy
mv ecosystem.single.config.js optimized-proxy/

# 5. Запустите
./optimize-pm2-processes.sh
```

---

## 📋 **Метод 3: Ручные команды (если скрипт не работает)**

### 🛠️ **Пошаговые команды:**

```bash
# 1. Проверить текущие процессы
pm2 list

# 2. Остановить все процессы
pm2 stop all
pm2 delete all

# 3. Очистить PM2
pm2 flush
pm2 kill

# 4. Подождать 3 секунды
sleep 3

# 5. Перейти в папку с кодом
cd /path/to/your/optimized-proxy

# 6. Создать папку для логов
mkdir -p logs

# 7. Запустить оптимизированную конфигурацию
pm2 start ecosystem.single.config.js --env production

# 8. Сохранить конфигурацию
pm2 save

# 9. Проверить результат
pm2 list
```

---

## 🛡️ **Безопасный запуск с бэкапом**

### 💾 **Перед оптимизацией:**

```bash
# 1. Создайте бэкап текущей конфигурации PM2
pm2 dump backup_$(date +%Y%m%d_%H%M%S).json

# 2. Сохраните текущий список процессов
pm2 list > pm2_processes_backup_$(date +%Y%m%d_%H%M%S).txt

# 3. Проверьте работоспособность перед изменениями
curl -I http://localhost:3000/ | head -1

# 4. Теперь запускайте оптимизацию
./optimize-pm2-processes.sh
```

### ↩️ **Откат в случае проблем:**

```bash
# Если что-то пошло не так, восстановите из бэкапа
pm2 kill
pm2 resurrect backup_YYYYMMDD_HHMMSS.json

# Или запустите fallback процесс
pm2 start /path/to/enhanced-simple-proxy.js --name fallback-proxy
```

---

## 🔍 **Диагностика и проверка**

### ✅ **После запуска проверьте:**

```bash
# 1. Статус PM2 процессов
pm2 list

# 2. Работоспособность endpoints
curl -s http://localhost:3000/health | jq .status
curl -s http://localhost:3000/health/metrics | jq .uptime

# 3. Основной прокси
curl -I http://localhost:3000/

# 4. Логи процесса
pm2 logs enhanced-proxy-single --lines 20

# 5. Мониторинг ресурсов
pm2 monit
```

### 📊 **Ожидаемый результат:**
```bash
pm2 list
# Должен показать:
# enhanced-proxy-single | online | ~56MB memory
```

---

## 🚨 **Возможные проблемы и решения**

### ❌ **Проблема**: "Permission denied"
```bash
# Решение: Добавить права на выполнение
chmod +x optimize-pm2-processes.sh
```

### ❌ **Проблема**: "pm2: command not found"
```bash
# Решение: Установить PM2
npm install -g pm2
# или
sudo npm install -g pm2
```

### ❌ **Проблема**: "No such file or directory"
```bash
# Решение: Найти правильный путь
find / -name "enhanced-simple-proxy.js" 2>/dev/null
cd /path/to/found/directory
```

### ❌ **Проблема**: Скрипт висит на команде
```bash
# Решение: Нажать Ctrl+C и запустить команды вручную
# Используйте "Метод 3: Ручные команды"
```

---

## 🎯 **Быстрый старт - одной командой**

### ⚡ **Если у вас есть SSH доступ:**

```bash
# Скопируйте и выполните эту команду на сервере
curl -s https://raw.githubusercontent.com/iLifeCreator/glideproxy/enhanced-proxy-v2.5/optimize-pm2-processes.sh | bash
```

**⚠️ Внимание**: Этот способ выполнит скрипт без возможности просмотра - используйте только если доверяете коду.

---

## 📞 **Если нужна помощь**

### 🆘 **Если возникли проблемы:**

1. **Покажите текущий статус:**
   ```bash
   pm2 list
   ps aux | grep node
   ```

2. **Покажите структуру папок:**
   ```bash
   ls -la /opt/
   find /opt -name "*.js" | grep proxy
   ```

3. **Проверьте логи:**
   ```bash
   pm2 logs --lines 50
   ```

4. **Отправьте результаты** - я помогу диагностировать проблему!

---

## ✅ **После успешного запуска**

Вы увидите:
- ✅ **1 процесс** вместо 3
- ✅ **~56MB памяти** вместо >200MB  
- ✅ **Все endpoints работают**
- ✅ **Улучшенная производительность**

**Ваш сервер будет работать оптимальнее!** 🚀