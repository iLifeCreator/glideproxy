# ⚡ Быстрая оптимизация PM2 на сервере

## 🎯 **3 простых шага для запуска**

### 1️⃣ **Подключитесь к серверу**
```bash
ssh root@5.129.215.152
```

### 2️⃣ **Найдите папку проекта**
```bash
# Попробуйте эти пути:
cd /opt/glide-proxy && ls -la
# или
cd /home/glide-proxy && ls -la  
# или
find / -name "enhanced-simple-proxy.js" 2>/dev/null
```

### 3️⃣ **Запустите оптимизацию**
```bash
# Способ А: Если скрипт есть
./optimize-pm2-processes.sh

# Способ Б: Скачать и запустить
wget https://raw.githubusercontent.com/iLifeCreator/glideproxy/enhanced-proxy-v2.5/optimize-pm2-processes.sh
chmod +x optimize-pm2-processes.sh
./optimize-pm2-processes.sh
```

---

## ✅ **Проверка результата**
```bash
pm2 list
# Должен показать: enhanced-proxy-single (~56MB)

curl http://localhost:3000/health
# Должен ответить: {"status":"healthy"}
```

---

## 🆘 **Если не работает - ручные команды**
```bash
pm2 stop all && pm2 delete all
pm2 kill
sleep 3
cd /path/to/optimized-proxy
pm2 start ecosystem.single.config.js --env production
pm2 save
pm2 list
```

**Готово! Теперь 1 процесс вместо 3 и 74% экономии памяти!** 🎉