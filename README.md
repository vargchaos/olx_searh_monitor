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

cat ~/README.md
