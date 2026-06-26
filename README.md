bash ~/install_olx_monitor.sh


## 🔧 Налаштування

### Telegram Bot

1. Напиши @BotFather у Telegram
2. Команда `/newbot`
3. Придумай ім'я і юзернейм
4. Скопіюй **Bot Token** - вставь в інтерфейсі
5. Напиши @userinfobot - отримаєш **Chat ID**

### OLX Пошук

1. Роби пошук на olx.ua
2. Скопіюй посилання з браузера
3. Вставь в інтерфейс через "Додати новий"
4. Поставь галочку та натисни "Застосувати"

## 📁 Структура файлів
/root/olx_monitor/

├── olx_notify.py           # Основний скрипт моніторингу

├── olx_server.py           # Flask API сервер

├── olx_monitor_ui.html     # Веб-інтерфейс

├── olx_searches.json       # Конфіг пошуків (автоматично)

└── olx_config.json         # Конфіг Telegram (автоматично)

## 📡 API Endpoints

### Config
```bash
GET  /api/config              # Отримати конфіг
POST /api/config              # Зберегти конфіг
```

### Searches
```bash
GET    /api/searches          # Список пошуків
POST   /api/searches          # Додати пошук
DELETE /api/searches/<id>     # Видалити пошук
PUT    /api/searches/<id>/toggle  # Увімкнути/вимкнути
```

### Apply
```bash
POST /api/apply              # Застосувати зміни до скрипту
```

## 🛠️ Налагодження

### Перевір логи Flask сервера
```bash
tail -f /var/log/olx_server.log
```

### Перевір логи моніторингу
```bash
tail -f /var/log/olx_notify.log
```

### Перевір чи скрипт запущений
```bash
ps aux | grep olx
```

## 🐳 Docker (опціонально)

```bash
docker build -t olx-monitor .
docker run -d -p 5000:5000 -p 8000:8000 -v /root/olx_monitor:/app olx-monitor
```

## 📝 Приклад конфіга

### olx_searches.json
```json
[
  {
    "url": "https://www.olx.ua/uk/elektronika/...",
    "active": true
  }
]
```

### olx_config.json
```json
{
  "bot_token": "123456:ABC-DEF1234...",
  "chat_id": 123456789
}
```

## ⚠️ Важливо

- **Не ділися токеном бота!** Якщо вже поділився - відкличи його через @BotFather
- Інтерфейс доступний локально на порту 8000
- Для доступу з іншої машини - змініть `localhost` на IP адресу сервера

## 🤝 Контрибютинг

Приватний проект. Пропозиції - в Issues.

## 📄 Ліцензія

MIT

---

**Автор:** Володимир  
**Статус:** Production Ready  
**Остання оновка:** 2026-06-24
READMEEOF

## 🔧 Детальне налаштування

### Встанови залежності вручну

```bash
pip3 install flask flask-cors requests beautifulsoup4 --break-system-packages
```

### Запусти сервіси окремо

**Flask API:**
```bash
python3 ~/olx_monitor/olx_server.py
```

**HTTP сервер для UI:**
```bash
cd ~/olx_monitor && python3 -m http.server 8000
```

**Моніторинг (один раз):**
```bash
python3 ~/olx_monitor/olx_notify.py
```

### Налаштуй автозапуск

**Через systemd (рекомендується):**

```bash
cat > /etc/systemd/system/olx-monitor.service << EOF
[Unit]
Description=OLX Monitor
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/olx_monitor
ExecStart=/usr/bin/python3 /root/olx_monitor/olx_server.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable olx-monitor
systemctl start olx-monitor
```

**Через crontab:**

```bash
crontab -e
# Додай для лунікс користувача:
@reboot cd /root/olx_monitor && nohup python3 olx_server.py > /var/log/olx_server.log 2>&1 &
@reboot cd /root/olx_monitor && nohup python3 -m http.server 8000 > /var/log/http_ui.log 2>&1 &
*/2 * * * * python3 /root/olx_monitor/olx_notify.py >> /var/log/olx_notify.log 2>&1
```

## 📡 REST API

### Config Endpoints

```bash
# Отримати конфіг
curl http://localhost:5000/api/config

# Зберегти конфіг
curl -X POST http://localhost:5000/api/config \
  -H "Content-Type: application/json" \
  -d '{"bot_token": "...", "chat_id": 123456}'
```

### Searches Endpoints

```bash
# Список пошуків
curl http://localhost:5000/api/searches

# Додати пошук
curl -X POST http://localhost:5000/api/searches \
  -H "Content-Type: application/json" \
  -d '{"url": "https://..."}'

# Видалити пошук
curl -X DELETE http://localhost:5000/api/searches/0

# Увімкнути/вимкнути
curl -X PUT http://localhost:5000/api/searches/0/toggle
```

### Apply Changes

```bash
# Застосувати налаштування до скрипту
curl -X POST http://localhost:5000/api/apply
```

## 🛠️ Налагодження

### Перевір статус сервісів

```bash
# Flask сервер
ps aux | grep olx_server.py

# HTTP сервер
ps aux | grep http.server

# Моніторинг у logах
tail -f /var/log/olx_notify.log
```

### Потрібна допомога?

1. **Сервер не запускається:**
```bash
   python3 ~/olx_monitor/olx_server.py
```
   Подивись помилку безпосередньо

2. **Не приходять сповіщення:**
```bash
   cat ~/olx_monitor/olx_config.json
   cat ~/olx_monitor/olx_searches.json
   python3 ~/olx_monitor/olx_notify.py
```

3. **Очисти логи:**
```bash
   > /var/log/olx_notify.log
   > /var/log/olx_server.log
```

## 📝 Приклади конфігів

### olx_config.json
```json
{
  "bot_token": "7879913057:AAEaaRUPFs0NWGZreoqj-i3y5INmRGgQLgc",
  "chat_id": 254266061
}
```

### olx_searches.json
```json
[
  {
    "url": "https://www.olx.ua/uk/elektronika/...",
    "active": true
  },
  {
    "url": "https://www.olx.ua/uk/nehruuchosty/...",
    "active": false
  }
]
```

## ⚠️ Важливо

- **🔐 Не ділись токеном бота!** Якщо вже поділився - відкличи його через [@BotFather](https://t.me/BotFather) → `/mybots` → выбери бота → **Revoke current token**
- 🔗 Інтерфейс доступний локально на `http://localhost:8000`
- 📱 Для доступу з іншої машини - замініть `localhost` на IP адресу сервера
- 🌐 Переконайся що порти 5000 та 8000 вільні

## 🚀 Продвинуте використання

### Моніторинг кількох категорій

Просто додай різні пошуки через веб-інтерфейс. Активуй ті що потрібні.

### Зміна інтервалу моніторингу

Відкрий `crontab -e` та змініть `*/2` (кожні 2 хвилини):
```bash
# Кожну хвилину
* * * * * python3 ~/olx_monitor/olx_notify.py

# Кожні 5 хвилин
*/5 * * * * python3 ~/olx_monitor/olx_notify.py

# Кожну годину
0 * * * * python3 ~/olx_monitor/olx_notify.py
```

### Запуск на Proxmox/NAS

Все працює з коробки! Просто запусти скрипт у Proxmox LXC контейнері або на NAS.

## 🤝 Контрибютинг

Найди баг? Є ідея як поліпшити?

Відкрий [Issue](https://github.com/user/olx-monitor/issues) або [Pull Request](https://github.com/user/olx-monitor/pulls)

## 📄 Ліцензія

MIT License - див. [LICENSE](LICENSE)

## 👤 Автор

**Володимир**
- 🐙 GitHub: [@user](https://github.com/vargchaos)
- 📧 Email: vargchaos@gmail.com

---

## 📊 Статус проекту

| Статус | Версія | Дата |
|--------|--------|------|
| ✅ Stable | 1.0.0 | 2026-06-24 |
| ✨ Features | 2 API endpoints | Working |
| 🐛 Bugs | 0 known | Fixed |

---

**Якщо проект тобі допоміг - дай ⭐ на GitHub!**

[⬆ Повернутися на топ](#-olx-monitor)
READMEEOF

cat ~/README.md
