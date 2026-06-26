cat > ~/install_olx_monitor.sh << 'INSTALLEOF'
#!/bin/bash

echo "🔍 OLX Monitor - Installation"
echo "=============================="

# Встанови залежності
echo "📦 Встановлюю залежності..."
pip3 install flask flask-cors requests beautifulsoup4 --break-system-packages 2>/dev/null

# Дозволи вибрати директорію
INSTALL_DIR="${1:-.}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "📝 Встановлюю в: $INSTALL_DIR"

# olx_notify.py
cat > olx_notify.py << 'ENDSCRIPT'
import requests, json, hashlib
from bs4 import BeautifulSoup
from pathlib import Path
import urllib3
urllib3.disable_warnings()

SCRIPT_DIR = Path(__file__).parent
CONFIG_FILE = SCRIPT_DIR / "olx_config.json"
SEARCHES_FILE = SCRIPT_DIR / "olx_searches.json"
SEEN_FILE = SCRIPT_DIR / "olx_seen.json"
HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
BOT_TOKEN = ""
CHAT_ID = 0
OLX_URL = ""

def load_config():
    global BOT_TOKEN, CHAT_ID
    if CONFIG_FILE.exists():
        config = json.loads(CONFIG_FILE.read_text())
        BOT_TOKEN = config.get('bot_token', '')
        CHAT_ID = config.get('chat_id', 0)

def get_listings():
    if not OLX_URL:
        return []
    r = requests.get(OLX_URL, headers=HEADERS, timeout=15)
    soup = BeautifulSoup(r.text, "html.parser")
    items = []
    for card in soup.select("[data-cy='l-card']"):
        link_tag = card.select_one("a")
        title_tag = card.select_one("h4")
        price_tag = card.select_one("[data-testid='ad-price']")
        if not link_tag or not title_tag:
            continue
        href = link_tag["href"]
        url = href if href.startswith("http") else "https://www.olx.ua" + href.split("#")[0]
        url = url.split("?")[0]
        items.append({"id": hashlib.md5(url.encode()).hexdigest(), "title": title_tag.text.strip(), "price": price_tag.text.strip() if price_tag else "-", "url": url})
    return items

def load_seen():
    if SEEN_FILE.exists():
        return set(json.loads(SEEN_FILE.read_text()))
    return set()

def save_seen(ids):
    SEEN_FILE.write_text(json.dumps(list(ids)))

def notify(item):
    if not BOT_TOKEN or not CHAT_ID:
        return
    text = f"Нове: {item['title']}\nЦіна: {item['price']}\n{item['url']}"
    requests.post(f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage", json={"chat_id": CHAT_ID, "text": text}, verify=False, timeout=10)

def main():
    global OLX_URL
    load_config()
    if SEARCHES_FILE.exists():
        searches = json.loads(SEARCHES_FILE.read_text())
        if searches and searches[0].get('active'):
            OLX_URL = searches[0].get('url', '')
    if not OLX_URL:
        return
    seen = load_seen()
    listings = get_listings()
    new_ids = set()
    for item in listings:
        new_ids.add(item["id"])
        if item["id"] not in seen:
            notify(item)
    save_seen(seen | new_ids)

if __name__ == "__main__":
    main()
ENDSCRIPT

# olx_server.py
cat > olx_server.py << 'ENDSERVER'
from flask import Flask, jsonify, request
from flask_cors import CORS
import json
from pathlib import Path
import re

app = Flask(__name__)
CORS(app)

SCRIPT_DIR = Path(__file__).parent
SCRIPT_PATH = SCRIPT_DIR / 'olx_notify.py'
SEARCHES_FILE = SCRIPT_DIR / 'olx_searches.json'
CONFIG_FILE = SCRIPT_DIR / 'olx_config.json'

def load_config():
    if CONFIG_FILE.exists():
        return json.loads(CONFIG_FILE.read_text())
    return {"bot_token": "", "chat_id": ""}

def save_config(config):
    CONFIG_FILE.write_text(json.dumps(config, indent=2))

def load_searches():
    if SEARCHES_FILE.exists() and SEARCHES_FILE.stat().st_size > 2:
        data = json.loads(SEARCHES_FILE.read_text())
        if data:
            return data
    return []

def save_searches(searches):
    SEARCHES_FILE.write_text(json.dumps(searches, indent=2, ensure_ascii=False))

def update_script(active_searches, config):
    try:
        with open(SCRIPT_PATH, 'r', encoding='utf-8') as f:
            content = f.read()
        new_url = active_searches[0] if active_searches else ""
        content = re.sub(r'BOT_TOKEN = "[^"]*"', f'BOT_TOKEN = "{config.get("bot_token", "")}"', content)
        content = re.sub(r'CHAT_ID = \d+', f'CHAT_ID = {config.get("chat_id", 0)}', content)
        content = re.sub(r'OLX_URL = "[^"]*"', f'OLX_URL = "{new_url}"', content)
        with open(SCRIPT_PATH, 'w', encoding='utf-8') as f:
            f.write(content)
    except:
        pass

@app.route('/api/config', methods=['GET'])
def get_config():
    return jsonify(load_config())

@app.route('/api/config', methods=['POST'])
def set_config():
    save_config(request.json)
    return jsonify({'status': 'ok'})

@app.route('/api/searches', methods=['GET'])
def get_searches():
    return jsonify(load_searches())

@app.route('/api/searches', methods=['POST'])
def save_search():
    searches = load_searches()
    url = request.json.get('url', '').strip()
    if url and not any(s['url'] == url for s in searches):
        searches.append({'url': url, 'active': True})
        save_searches(searches)
        return jsonify({'status': 'ok', 'searches': searches})
    return jsonify({'status': 'error'}), 400

@app.route('/api/searches/<int:idx>', methods=['DELETE'])
def delete_search(idx):
    searches = load_searches()
    if 0 <= idx < len(searches):
        searches.pop(idx)
        save_searches(searches)
    return jsonify({'status': 'ok'})

@app.route('/api/searches/<int:idx>/toggle', methods=['PUT'])
def toggle_search(idx):
    searches = load_searches()
    if 0 <= idx < len(searches):
        searches[idx]['active'] = not searches[idx]['active']
        save_searches(searches)
    return jsonify({'status': 'ok', 'searches': searches})

@app.route('/api/apply', methods=['POST'])
def apply_changes():
    searches = load_searches()
    config = load_config()
    active = [s['url'] for s in searches if s['active']]
    if active:
        update_script(active, config)
        return jsonify({'status': 'ok', 'message': '✓ Встановлено'})
    return jsonify({'status': 'error'}), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
ENDSERVER

# olx_monitor_ui.html
cat > olx_monitor_ui.html << 'ENDHTML'
<!DOCTYPE html>
<html lang="uk">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OLX Monitor</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f5f5f5; padding: 20px; }
        .container { max-width: 900px; margin: 0 auto; background: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); padding: 30px; }
        h1 { color: #333; margin-bottom: 30px; }
        h3 { color: #555; margin-bottom: 15px; font-size: 18px; }
        .section { margin-bottom: 30px; padding-bottom: 30px; border-bottom: 1px solid #eee; }
        .section:last-child { border-bottom: none; }
        label { display: block; font-weight: 500; margin-bottom: 8px; color: #555; font-size: 14px; }
        .form-row { display: flex; gap: 20px; margin-bottom: 15px; }
        .form-group { flex: 1; }
        input[type="text"], input[type="number"] { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 4px; font-size: 14px; }
        input:focus { outline: none; border-color: #007bff; box-shadow: 0 0 0 2px rgba(0,123,255,0.1); }
        button { padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; font-weight: 500; font-size: 14px; }
        .btn-primary { background: #007bff; color: white; }
        .btn-primary:hover { background: #0056b3; }
        .btn-danger { background: #dc3545; color: white; padding: 6px 12px; }
        .btn-danger:hover { background: #c82333; }
        .btn-success { background: #28a745; color: white; padding: 12px 24px; font-size: 16px; }
        .btn-success:hover { background: #218838; }
        .btn-save { background: #17a2b8; color: white; padding: 8px 16px; font-size: 13px; }
        .btn-save:hover { background: #138496; }
        .url-list { display: flex; flex-direction: column; gap: 12px; }
        .url-input-group { display: flex; gap: 10px; }
        #newUrl { flex: 1; }
        .url-item { display: flex; align-items: center; gap: 12px; padding: 12px; background: #f9f9f9; border-radius: 4px; border: 1px solid #eee; }
        .url-item input[type="checkbox"] { width: 20px; height: 20px; cursor: pointer; }
        .url-item-text { flex: 1; word-break: break-all; font-size: 13px; color: #666; }
        .alert { padding: 12px; border-radius: 4px; margin-top: 12px; font-size: 13px; }
        .alert-success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 OLX Monitor</h1>
        
        <div class="section">
            <h3>⚙️ Telegram Bot</h3>
            <div class="form-row">
                <div class="form-group"><label>Bot Token:</label><input type="text" id="botToken" placeholder="123456:ABC-DEF..."></div>
                <div class="form-group" style="flex: 0.5;"><label>Chat ID:</label><input type="number" id="chatId" placeholder="123456789"></div>
            </div>
            <button class="btn-save" onclick="saveConfig()">💾 Зберегти</button>
            <div id="configMessage"></div>
        </div>
        
        <div class="section">
            <h3>🔗 OLX Пошуки</h3>
            <label>Додати новий:</label>
            <div class="url-input-group">
                <input type="text" id="newUrl" placeholder="Посилання OLX пошуку...">
                <button class="btn-primary" onclick="addUrl()">➕ Додати</button>
            </div>
            <label style="margin-top: 15px;">Активні пошуки:</label>
            <div class="url-list" id="urlList">Завантажу...</div>
        </div>
        
        <div class="section">
            <button class="btn-success" onclick="applyChanges()">✓ Застосувати</button>
            <div id="message"></div>
        </div>
    </div>

    <script>
        const API = 'http://localhost:5000/api';
        function loadConfig() { fetch(`${API}/config`).then(r => r.json()).then(c => {document.getElementById('botToken').value = c.bot_token || ''; document.getElementById('chatId').value = c.chat_id || '';}); }
        function saveConfig() { const token = document.getElementById('botToken').value.trim(); const chatId = parseInt(document.getElementById('chatId').value) || 0; if (!token || !chatId) return alert('Заповни всі поля'); fetch(`${API}/config`, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({bot_token: token, chat_id: chatId})}).then(() => {document.getElementById('configMessage').innerHTML = '<div class="alert alert-success">✓ Збережено</div>'; setTimeout(() => document.getElementById('configMessage').innerHTML = '', 3000);}); }
        function loadSearches() { fetch(`${API}/searches`).then(r => r.json()).then(s => {window.searches = s; renderList();}); }
        function renderList() { const list = document.getElementById('urlList'); if (!window.searches || !window.searches.length) {list.innerHTML = '<p style="color: #999;">Пошуків не додано</p>'; return;} list.innerHTML = window.searches.map((s, i) => `<div class="url-item"><input type="checkbox" ${s.active ? 'checked' : ''} onchange="toggleSearch(${i})"><div class="url-item-text">${s.url.substring(0, 80)}...</div><button class="btn-danger" onclick="deleteSearch(${i})">✕</button></div>`).join(''); }
        function addUrl() { const url = document.getElementById('newUrl').value.trim(); if (!url || !url.includes('olx.ua')) return alert('Некоректне посилання'); fetch(`${API}/searches`, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({url})}).then(r => r.json()).then(d => {window.searches = d.searches; renderList(); document.getElementById('newUrl').value = '';}); }
        function deleteSearch(idx) { fetch(`${API}/searches/${idx}`, {method: 'DELETE'}).then(() => loadSearches()); }
        function toggleSearch(idx) { fetch(`${API}/searches/${idx}/toggle`, {method: 'PUT'}).then(r => r.json()).then(d => {window.searches = d.searches; renderList();}); }
        function applyChanges() { const active = window.searches.filter(s => s.active); if (!active.length) return alert('Вибери хоча б один пошук'); document.getElementById('message').innerHTML = '<div class="alert alert-success">⏳ Застосовую...</div>'; fetch(`${API}/apply`, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({})}).then(r => r.json()).then(d => {document.getElementById('message').innerHTML = `<div class="alert alert-success">✓ ${d.message}</div>`;}); }
        loadConfig(); loadSearches();
    </script>
</body>
</html>
ENDHTML

# Ініціалізуй
echo "[]" > olx_searches.json
echo "{}" > olx_config.json

echo ""
echo "✅ Встановлено в: $INSTALL_DIR"
echo ""
echo "🚀 Запусти:"
echo "   nohup python3 $INSTALL_DIR/olx_server.py > /var/log/olx_server.log 2>&1 &"
echo "   cd $INSTALL_DIR && nohup python3 -m http.server 8000 > /var/log/http_ui.log 2>&1 &"
echo ""
echo "📋 Додай до cron (кожні 2 хвилини):"
echo "   crontab -e"
echo "   */2 * * * * python3 $INSTALL_DIR/olx_notify.py >> /var/log/olx_notify.log 2>&1"
echo ""
echo "🌐 Браузер: http://localhost:8000/olx_monitor_ui.html"
echo ""
echo "✅ Готово!"
INSTALLEOF

chmod +x ~/install_olx_monitor.sh
echo "✅ Оновлено: ~/install_olx_monitor.sh"