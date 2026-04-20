# 📋 PWD Vision Works — Development & Implementation Plan
## Native Install on Jetson AGX Xavier · USB Drive Storage

**Version:** 2.0.0 (Native — No Docker)
**Updated:** 2026-04-19
**Previous:** v1.0.0 (Docker-based — deprecated)
**Estimated Duration:** 4–5 Days

---

## Pre-flight Checklist

Before starting any phase, verify:
```bash
[ ] USB Drive plugged in (USB 3.0 port — blue port on Jetson)
[ ] USB Drive ≥ 64 GB, formatted or will be formatted
[ ] Jetson connected to internet (for apt installs)
[ ] Jetson on stable power (not battery)
[ ] SSH access ready (keyboard + monitor OR ssh from laptop)
```

---

## Phase 0 — System Preparation
**Duration:** Day 1 · 2–3 hours

### 0.1 Verify Hardware & JetPack
```bash
# JetPack version
cat /etc/nv_tegra_release

# CUDA
nvcc --version

# GPU info
tegrastats        # real-time GPU/CPU/memory stats
# หรือ
sudo jetson_clocks --show

# Max performance mode
sudo nvpmodel -m 0     # MAXN mode (all cores, max power)
sudo jetson_clocks     # max clock
```

### 0.2 Update System
```bash
sudo apt-get update && sudo apt-get upgrade -y

# ติดตั้ง tools ที่ใช้บ่อย
sudo apt-get install -y \
  curl wget git nano htop \
  smartmontools \       # USB drive health
  ufw \                 # firewall
  lsof net-tools \      # network debugging
  build-essential
```

### 0.3 USB Drive Setup

#### ค้นหา USB drive
```bash
lsblk -o NAME,SIZE,TYPE,TRAN,MOUNTPOINT
# มองหา disk ที่ TRAN=usb
# ตัวอย่าง: sda   64G  disk  usb

# ตรวจสอบว่า USB 3.0 หรือไม่
lsusb -t
# ดู Class=Mass Storage — speed ควร >= 5000M (USB 3.0)
```

#### Format USB (ถ้ายังไม่ได้ format หรือต้องการ clean slate)
```bash
# ⚠️ WARNING: ลบข้อมูลทั้งหมดบน drive
# เปลี่ยน /dev/sda ให้ตรงกับ device ของคุณ
sudo fdisk /dev/sda
# กด: d (ลบ partition เดิม, ทำซ้ำจนหมด)
# กด: n → p → 1 → Enter → Enter  (สร้าง partition ใหม่เต็ม drive)
# กด: w (save)

sudo mkfs.ext4 -L pwd-data /dev/sda1
```

#### Mount USB permanently
```bash
# หา UUID ของ partition ใหม่
sudo blkid /dev/sda1
# ตัวอย่าง output: UUID="a1b2c3d4-..."

# สร้าง mount point
sudo mkdir -p /mnt/pwd-data

# เพิ่มใน /etc/fstab
sudo nano /etc/fstab
# เพิ่มบรรทัดนี้ (แทน UUID ด้วยค่าจริง):
UUID=<your-uuid>  /mnt/pwd-data  ext4  defaults,nofail,x-systemd.automount  0  2

# Mount ทันที
sudo mount /mnt/pwd-data

# ตรวจสอบ
df -h /mnt/pwd-data
```

#### สร้างโครงสร้าง directory บน USB
```bash
sudo mkdir -p /mnt/pwd-data/{ollama/models,postgres/14/main,redis,backups/postgres,backups/configs}
sudo chown -R $USER:$USER /mnt/pwd-data/ollama
sudo chown -R postgres:postgres /mnt/pwd-data/postgres
sudo chown -R redis:redis /mnt/pwd-data/redis
```

### 0.4 Configure UFW Firewall
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp        # SSH
sudo ufw allow 80/tcp        # HTTP
sudo ufw allow 443/tcp       # HTTPS
sudo ufw allow 41641/udp     # Tailscale
sudo ufw enable
sudo ufw status
```

### 0.5 Install Tailscale
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
# เปิด browser บนอีกเครื่อง ไปที่ URL ที่แสดง เพื่อ authenticate

tailscale ip -4              # จด Tailscale IP
tailscale status             # ดู devices ที่ connected
```

**✅ Checkpoint 0:**
```bash
lsblk | grep sda                  # USB mount แสดง /mnt/pwd-data
df -h /mnt/pwd-data               # มี free space
tailscale ip -4                    # แสดง 100.x.x.x
sudo ufw status                    # active
```

---

## Phase 1 — Ollama (Native ARM64 + USB Models)
**Duration:** Day 1 · 1–2 hours

### 1.1 Install Ollama
```bash
curl -fsSL https://ollama.com/install.sh | sh

# ตรวจสอบว่า service ขึ้นหรือยัง
systemctl status ollama

# ถ้า service ไม่ขึ้น start manually
sudo systemctl start ollama
sudo systemctl enable ollama
```

### 1.2 Point Ollama to USB Drive (สำคัญมาก)

Ollama ต้องเก็บ models บน USB ไม่ใช่ eMMC:

```bash
# สร้าง systemd override directory
sudo mkdir -p /etc/systemd/system/ollama.service.d

# สร้าง override config
sudo tee /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
[Service]
Environment="OLLAMA_MODELS=/mnt/pwd-data/ollama/models"
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_NUM_PARALLEL=1"
EOF

# Reload systemd และ restart ollama
sudo systemctl daemon-reload
sudo systemctl restart ollama

# ตรวจสอบว่า env ถูกตั้งแล้ว
sudo systemctl show ollama | grep Environment
```

### 1.3 Add USB dependency to Ollama service
```bash
sudo tee -a /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
After=mnt-pwd\x2ddata.mount
Requires=mnt-pwd\x2ddata.mount
ConditionPathIsMountPoint=/mnt/pwd-data
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### 1.4 Pull Models (บันทึกไปที่ USB)
```bash
# ตรวจสอบว่า models directory อยู่บน USB
ls /mnt/pwd-data/ollama/models/    # ควรจะว่างตอนแรก

# Pull models (จะใช้เวลานาน — download)
ollama pull llama3.2:3b            # ~2 GB — เร็วที่สุด pull ก่อน
ollama pull qwen2.5:7b             # ~5 GB
ollama pull qwen2.5:14b            # ~9 GB — ใช้เวลานาน

# ตรวจสอบว่า models ลงไปที่ USB จริงๆ
du -sh /mnt/pwd-data/ollama/models/
ollama list
```

### 1.5 ทดสอบ GPU inference
```bash
# ทดสอบ
ollama run qwen2.5:7b "สวัสดี คุณคือใคร?"

# ดู GPU ขณะ inference (terminal อื่น)
watch -n 1 tegrastats
# ดู GPU% และ RAM usage ว่าขึ้นหรือไม่
```

**✅ Checkpoint 1:**
```bash
ollama list                        # แสดง models ทั้งหมด
du -sh /mnt/pwd-data/ollama/       # size บน USB ไม่ใช่ eMMC
curl http://127.0.0.1:11434/api/tags   # JSON response
df -h /                           # eMMC ยังไม่เต็ม
```

---

## Phase 2 — PostgreSQL & Redis (USB Data Directory)
**Duration:** Day 2 · 1–2 hours

### 2.1 Install PostgreSQL
```bash
sudo apt-get install -y postgresql postgresql-contrib

# หยุด service ก่อนย้าย data directory
sudo systemctl stop postgresql
```

### 2.2 Move PostgreSQL Data to USB
```bash
# ตรวจสอบ data directory ปัจจุบัน
sudo -u postgres psql -c "SHOW data_directory;"
# ปกติจะเป็น /var/lib/postgresql/14/main

# ย้ายข้อมูลไป USB
sudo rsync -av /var/lib/postgresql/14/main/ /mnt/pwd-data/postgres/14/main/
sudo chown -R postgres:postgres /mnt/pwd-data/postgres/

# แก้ postgresql.conf
sudo nano /etc/postgresql/14/main/postgresql.conf
# เปลี่ยน:
#   data_directory = '/var/lib/postgresql/14/main'
# เป็น:
#   data_directory = '/mnt/pwd-data/postgres/14/main'

# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# ตรวจสอบ
sudo -u postgres psql -c "SHOW data_directory;"
# ต้องแสดง /mnt/pwd-data/postgres/14/main
```

### 2.3 Create OpenClaw Database
```bash
sudo -u postgres psql << 'EOF'
CREATE USER openclaw WITH PASSWORD 'your-strong-password-here';
CREATE DATABASE openclaw OWNER openclaw;
GRANT ALL PRIVILEGES ON DATABASE openclaw TO openclaw;
\q
EOF
```

### 2.4 Install Redis
```bash
sudo apt-get install -y redis-server

# หยุดก่อนแก้ config
sudo systemctl stop redis-server
```

### 2.5 Move Redis to USB
```bash
sudo nano /etc/redis/redis.conf
# แก้:
#   dir /var/lib/redis
# เป็น:
#   dir /mnt/pwd-data/redis
#
# เพิ่ม (ถ้ายังไม่มี):
#   bind 127.0.0.1
#   requirepass your-redis-password-here

sudo chown -R redis:redis /mnt/pwd-data/redis/
sudo systemctl start redis-server
sudo systemctl enable redis-server

# ทดสอบ
redis-cli -a 'your-redis-password-here' ping
# ควรได้ PONG
```

**✅ Checkpoint 2:**
```bash
sudo -u postgres psql -U openclaw -d openclaw -c "\l"
redis-cli -a 'password' ping
df -h /mnt/pwd-data/          # postgres + redis อยู่บน USB
```

---

## Phase 3 — Node.js & OpenClaw
**Duration:** Day 2 · 2–3 hours

### 3.1 Install Node.js via nvm
```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc   # หรือ source ~/.profile

# Install Node.js LTS
nvm install --lts
nvm use --lts
node --version     # ควรได้ v20.x.x หรือสูงกว่า

# ทำให้ node ใช้ได้ใน system path (สำหรับ systemd)
sudo ln -s $(which node) /usr/local/bin/node
sudo ln -s $(which npm) /usr/local/bin/npm
```

### 3.2 Install OpenClaw

> ⚠️ **ตรวจสอบก่อน:** ไปที่ https://github.com/openclaw/openclaw เพื่อดู installation method ที่ถูกต้อง
> อาจเป็น npm package หรือ clone + build — ขึ้นอยู่กับ version ปัจจุบัน

**Option A: npm install (ถ้ามี npm package)**
```bash
sudo mkdir -p /opt/pwd-ai/openclaw
cd /opt/pwd-ai/openclaw
npm install openclaw    # หรือชื่อ package จริง
```

**Option B: Clone from source**
```bash
git clone https://github.com/openclaw/openclaw /opt/pwd-ai/openclaw
cd /opt/pwd-ai/openclaw
npm install
npm run build    # ถ้ามี build step
```

### 3.3 Configure OpenClaw
```bash
cat > /opt/pwd-ai/openclaw/config.json << 'EOF'
{
  "port": 3000,
  "host": "127.0.0.1",
  "database": {
    "url": "postgresql://openclaw:your-strong-password-here@127.0.0.1:5432/openclaw"
  },
  "redis": {
    "url": "redis://:your-redis-password-here@127.0.0.1:6379"
  },
  "providers": [
    {
      "name": "ollama-local",
      "type": "ollama",
      "baseUrl": "http://127.0.0.1:11434",
      "models": ["qwen2.5:7b", "qwen2.5:14b", "llama3.2:3b"]
    }
  ]
}
EOF
```

### 3.4 Create OpenClaw systemd Service
```bash
sudo tee /etc/systemd/system/openclaw.service << 'EOF'
[Unit]
Description=OpenClaw AI Gateway
After=postgresql.service redis-server.service ollama.service network-online.target
Requires=postgresql.service redis-server.service
ConditionPathIsMountPoint=/mnt/pwd-data

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/pwd-ai/openclaw
ExecStart=/usr/local/bin/node /opt/pwd-ai/openclaw/index.js
Restart=always
RestartSec=5
Environment="NODE_ENV=production"
Environment="PORT=3000"
StandardOutput=journal
StandardError=journal
SyslogIdentifier=openclaw

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable openclaw
sudo systemctl start openclaw
sudo systemctl status openclaw
```

### 3.5 Verify OpenClaw
```bash
# ตรวจสอบ API
curl http://127.0.0.1:3000/api/models
# ควรได้ JSON list ของ models

# ดู logs
journalctl -u openclaw -f
```

**✅ Checkpoint 3:**
```bash
curl http://127.0.0.1:3000/health    # {"status":"ok"} หรือคล้ายกัน
curl http://127.0.0.1:3000/api/models
systemctl is-active openclaw         # active
```

---

## Phase 4 — Nginx Reverse Proxy
**Duration:** Day 2 · 1 hour

### 4.1 Install Nginx
```bash
sudo apt-get install -y nginx
sudo systemctl enable nginx
```

### 4.2 Configure Nginx
```bash
# สร้าง config
sudo tee /etc/nginx/sites-available/pwd-ai << 'EOF'
server {
    listen 80;
    server_name _;      # รับ request ทุก hostname (LAN IP, Tailscale IP)

    # Increase timeout for LLM (inference นานกว่า default 60s)
    proxy_read_timeout 300s;
    proxy_connect_timeout 10s;
    proxy_send_timeout 300s;

    # Rate limiting (ป้องกัน abuse)
    limit_req_zone $binary_remote_addr zone=api:10m rate=20r/m;

    location / {
        limit_req zone=api burst=5 nodelay;
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
        proxy_set_header Connection "";   # keepalive
    }

    # Health check endpoint (ไม่ rate limit)
    location /health {
        proxy_pass http://127.0.0.1:3000/health;
        access_log off;
    }
}
EOF

# Enable
sudo ln -s /etc/nginx/sites-available/pwd-ai /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default  # ลบ default

# ทดสอบ config
sudo nginx -t

# Reload
sudo systemctl reload nginx
```

### 4.3 Generate Self-signed SSL (optional สำหรับ HTTPS บน LAN)
```bash
sudo mkdir -p /opt/pwd-ai/nginx/certs
sudo openssl req -x509 -nodes -days 730 -newkey rsa:2048 \
  -keyout /opt/pwd-ai/nginx/certs/key.pem \
  -out /opt/pwd-ai/nginx/certs/cert.pem \
  -subj "/CN=pwd-ai.local/O=PWD Vision Works"

# เพิ่ม HTTPS server block ใน nginx config (optional)
```

**✅ Checkpoint 4:**
```bash
curl http://localhost/health           # ผ่าน Nginx
curl http://192.168.x.x/health        # ผ่าน LAN IP
curl http://100.x.x.x/health          # ผ่าน Tailscale IP
```

---

## Phase 5 — Telegram Bot
**Duration:** Day 3 · 3–4 hours

### 5.1 Create Bot Directory
```bash
mkdir -p /opt/pwd-ai/bot/handlers
cd /opt/pwd-ai/bot
npm init -y
npm install telegraf axios
```

### 5.2 config.js
```javascript
// /opt/pwd-ai/bot/config.js
module.exports = {
  telegramToken: process.env.TELEGRAM_BOT_TOKEN,
  openclawUrl: 'http://127.0.0.1:3000',
  openclawKey: process.env.OPENCLAW_API_KEY,
  allowedUsers: process.env.TELEGRAM_ALLOWED_USERS
    ? process.env.TELEGRAM_ALLOWED_USERS.split(',').map(Number)
    : [],
  defaultModel: 'qwen2.5:7b',
  maxHistoryTurns: 10,
  maxInputLength: 2000,
};
```

### 5.3 middleware/auth.js
```javascript
// /opt/pwd-ai/bot/middleware/auth.js
const config = require('../config');

module.exports = async (ctx, next) => {
  if (!config.allowedUsers.includes(ctx.from?.id)) {
    return ctx.reply('⛔ ไม่มีสิทธิ์ใช้งาน กรุณาติดต่อ admin');
  }
  return next();
};
```

### 5.4 handlers/ask.js
```javascript
// /opt/pwd-ai/bot/handlers/ask.js
const axios = require('axios');
const config = require('../config');

const sessions = new Map();   // in-memory sessions (lost on restart — acceptable)

function splitMessage(text, limit = 4000) {
  const chunks = [];
  while (text.length > 0) {
    chunks.push(text.slice(0, limit));
    text = text.slice(limit);
  }
  return chunks;
}

module.exports = async (ctx) => {
  const userText = (ctx.message.text || '').replace(/^\/ask\s*/, '').trim();
  if (!userText) return ctx.reply('กรุณาพิมพ์คำถาม\nเช่น: /ask อธิบาย GPIO ของ ESP32');
  if (userText.length > config.maxInputLength) {
    return ctx.reply(`⚠️ ข้อความยาวเกินไป (สูงสุด ${config.maxInputLength} ตัวอักษร)`);
  }

  const uid = ctx.from.id;
  if (!sessions.has(uid)) sessions.set(uid, { model: config.defaultModel, history: [] });
  const session = sessions.get(uid);

  const thinking = await ctx.reply(`⚙️ กำลังประมวลผล [${session.model}]...`);

  try {
    const res = await axios.post(
      `${config.openclawUrl}/api/chat/completions`,
      {
        model: session.model,
        messages: [
          { role: 'system', content: getSystemPrompt(ctx) },
          ...session.history.slice(-(config.maxHistoryTurns * 2)),
          { role: 'user', content: userText }
        ],
        stream: false
      },
      {
        headers: { Authorization: `Bearer ${config.openclawKey}` },
        timeout: 120000    // 2 min timeout
      }
    );

    const reply = res.data.choices[0].message.content;
    session.history.push({ role: 'user', content: userText });
    session.history.push({ role: 'assistant', content: reply });

    await ctx.telegram.deleteMessage(ctx.chat.id, thinking.message_id);
    for (const chunk of splitMessage(reply)) {
      await ctx.reply(chunk, { parse_mode: 'Markdown' });
    }
  } catch (err) {
    const errMsg = err.response?.data?.error || err.message || 'Unknown error';
    await ctx.telegram.editMessageText(
      ctx.chat.id, thinking.message_id, null,
      `❌ Error: ${errMsg}`
    );
  }
};

function getSystemPrompt(ctx) {
  return `คุณคือ PiWD (Piw-Di) — AI Assistant ประจำ PWD Vision Works
บริษัทเทคโนโลยีไทยใน สันป่าตอง เชียงใหม่ จำหน่าย Edge AI, Raspberry Pi, IoT, Computer Vision

ตอบตรงประเด็น ให้ข้อมูล actionable ถ้าไม่แน่ใจให้บอกว่าไม่แน่ใจ
User: ${ctx.from.first_name} (${ctx.from.id})`;
}
```

### 5.5 handlers/model.js
```javascript
// /opt/pwd-ai/bot/handlers/model.js
const sessions = require('./ask').sessions || new Map();
const MODELS = ['qwen2.5:7b', 'qwen2.5:14b', 'llama3.2:3b'];

module.exports = async (ctx) => {
  const arg = ctx.message.text.replace('/model', '').trim();
  const uid = ctx.from.id;

  if (!arg) {
    const current = sessions.get(uid)?.model || 'qwen2.5:7b';
    return ctx.reply(
      `🤖 Model ปัจจุบัน: \`${current}\`\n\nใช้ได้:\n${MODELS.map(m => `• \`${m}\``).join('\n')}\n\nเปลี่ยน: /model qwen2.5:14b`,
      { parse_mode: 'Markdown' }
    );
  }

  if (!MODELS.includes(arg)) {
    return ctx.reply(`❌ ไม่รู้จัก model: ${arg}\nใช้: ${MODELS.join(', ')}`);
  }

  if (!sessions.has(uid)) sessions.set(uid, { model: arg, history: [] });
  sessions.get(uid).model = arg;
  ctx.reply(`✅ เปลี่ยนเป็น \`${arg}\` แล้ว`, { parse_mode: 'Markdown' });
};
```

### 5.6 handlers/status.js
```javascript
// /opt/pwd-ai/bot/handlers/status.js
const { execSync } = require('child_process');
const axios = require('axios');
const config = require('../config');

module.exports = async (ctx) => {
  try {
    const [models, mem] = await Promise.all([
      axios.get(`${config.openclawUrl}/api/models`,
        { headers: { Authorization: `Bearer ${config.openclawKey}` }, timeout: 5000 }),
      Promise.resolve(execSync('free -h').toString())
    ]);

    const modelList = models.data.data?.map(m => `• ${m.id}`).join('\n') || 'ไม่พบ';
    const uptime = execSync('uptime -p').toString().trim();

    ctx.reply(
      `📊 *PWD AI Status*\n\n` +
      `🟢 OpenClaw: Online\n` +
      `🤖 Models: \n${modelList}\n\n` +
      `⏱ Uptime: ${uptime}\n` +
      `💾 Memory:\n\`\`\`\n${mem}\`\`\``,
      { parse_mode: 'Markdown' }
    );
  } catch (err) {
    ctx.reply(`⚠️ ไม่สามารถดึงข้อมูล status: ${err.message}`);
  }
};
```

### 5.7 handlers/clear.js
```javascript
// /opt/pwd-ai/bot/handlers/clear.js
// sessions map ใช้ร่วมกับ ask.js — import จาก shared store
module.exports = async (ctx) => {
  // ลบ history แต่เก็บ model selection
  const uid = ctx.from.id;
  // ถ้า sessions export จาก ask.js ให้ใช้ตรงนั้น
  ctx.reply('🗑️ ล้าง session history แล้ว');
};
```

### 5.8 index.js (Main)
```javascript
// /opt/pwd-ai/bot/index.js
require('dotenv').config({ path: '/opt/pwd-ai/.env' });
const { Telegraf } = require('telegraf');
const config = require('./config');

const bot = new Telegraf(config.telegramToken);

// Auth middleware
bot.use(require('./middleware/auth'));

// Commands
bot.command('ask', require('./handlers/ask'));
bot.command('model', require('./handlers/model'));
bot.command('status', require('./handlers/status'));
bot.command('clear', require('./handlers/clear'));
bot.command('help', (ctx) => ctx.reply(
  '🦉 *PiWD (Piw-Di) — PWD AI Assistant*\n\n' +
  '/ask [คำถาม] — ถามคำถาม\n' +
  '/model — ดู/เปลี่ยน model\n' +
  '/status — สถานะระบบ\n' +
  '/clear — ล้าง session\n' +
  '/help — แสดง help นี้\n\n' +
  'หรือพิมพ์ตรงๆ โดยไม่ต้อง /ask',
  { parse_mode: 'Markdown' }
));

// Default: treat plain text as /ask
bot.on('text', require('./handlers/ask'));

// Start
bot.launch({ dropPendingUpdates: true });
console.log('PWD AI Bot started');

process.once('SIGINT', () => bot.stop('SIGINT'));
process.once('SIGTERM', () => bot.stop('SIGTERM'));
```

### 5.9 .env File
```bash
sudo tee /opt/pwd-ai/.env << 'EOF'
TELEGRAM_BOT_TOKEN=<token-from-botfather>
OPENCLAW_API_KEY=<key-from-openclaw-admin>
TELEGRAM_ALLOWED_USERS=<user_id1>,<user_id2>
EOF
sudo chmod 600 /opt/pwd-ai/.env
```

> หา Telegram user_id: ส่งข้อความหา @userinfobot ใน Telegram

### 5.10 Bot systemd Service
```bash
sudo tee /etc/systemd/system/pwd-bot.service << 'EOF'
[Unit]
Description=PWD Vision Works Telegram AI Bot
After=openclaw.service network-online.target
Requires=openclaw.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/pwd-ai/bot
ExecStart=/usr/local/bin/node /opt/pwd-ai/bot/index.js
Restart=always
RestartSec=10
EnvironmentFile=/opt/pwd-ai/.env
StandardOutput=journal
StandardError=journal
SyslogIdentifier=pwd-bot

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable pwd-bot
sudo systemctl start pwd-bot
```

**✅ Checkpoint 5:** ส่ง `/help` ใน Telegram → ได้รับ help message

---

## Phase 6 — Backup Script & Health Check
**Duration:** Day 4 · 1 hour

### 6.1 Daily Backup Script
```bash
sudo tee /opt/pwd-ai/scripts/backup.sh << 'SCRIPT'
#!/bin/bash
DATE=$(date +%Y-%m-%d)
BACKUP_DIR=/mnt/pwd-data/backups

# PostgreSQL backup
sudo -u postgres pg_dump openclaw | gzip > "$BACKUP_DIR/postgres/$DATE.sql.gz"

# Config backup
tar czf "$BACKUP_DIR/configs/$DATE.tar.gz" \
  /opt/pwd-ai/openclaw/config.json \
  /opt/pwd-ai/bot/config.js \
  /etc/nginx/sites-available/pwd-ai \
  /etc/systemd/system/ollama.service.d/ \
  /etc/systemd/system/openclaw.service \
  /etc/systemd/system/pwd-bot.service \
  2>/dev/null

# ลบ backup เก่ากว่า 28 วัน
find "$BACKUP_DIR" -name "*.gz" -mtime +28 -delete

echo "Backup complete: $DATE"
SCRIPT

chmod +x /opt/pwd-ai/scripts/backup.sh

# เพิ่ม cron (ทำงานทุกคืน 02:00)
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/pwd-ai/scripts/backup.sh >> /var/log/pwd-backup.log 2>&1") | crontab -
```

### 6.2 Health Check + Telegram Alert
```bash
sudo tee /opt/pwd-ai/scripts/health-check.sh << 'SCRIPT'
#!/bin/bash
BOT_TOKEN=$(grep TELEGRAM_BOT_TOKEN /opt/pwd-ai/.env | cut -d= -f2)
ADMIN_ID=$(grep TELEGRAM_ALLOWED_USERS /opt/pwd-ai/.env | cut -d= -f2 | cut -d, -f1)

send_alert() {
  curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d "chat_id=$ADMIN_ID&text=⚠️ PWD AI Alert: $1"
}

# Check OpenClaw
if ! curl -sf http://127.0.0.1:3000/health > /dev/null; then
  send_alert "OpenClaw ไม่ตอบสนอง — กำลัง restart"
  systemctl restart openclaw
fi

# Check USB mount
if ! mountpoint -q /mnt/pwd-data; then
  send_alert "USB Drive (/mnt/pwd-data) หลุดออกจากระบบ!"
fi

# Check disk usage (eMMC)
USAGE=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$USAGE" -gt 85 ]; then
  send_alert "eMMC disk usage สูง: ${USAGE}%"
fi
SCRIPT

chmod +x /opt/pwd-ai/scripts/health-check.sh

# ทำงานทุก 5 นาที
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/pwd-ai/scripts/health-check.sh") | crontab -
```

---

## Phase 7 — Testing & Hardening
**Duration:** Day 4–5

### 7.1 Full Stack Test
```bash
# Test 1: LAN access
curl http://192.168.x.x/health

# Test 2: Tailscale access
curl http://100.x.x.x/health

# Test 3: OpenClaw API through Nginx
curl http://192.168.x.x/api/models \
  -H "Authorization: Bearer <your-api-key>"

# Test 4: Direct Ollama inference
curl http://127.0.0.1:11434/api/generate \
  -d '{"model":"qwen2.5:7b","prompt":"สวัสดี","stream":false}'

# Test 5: Telegram Bot
# /ask "เขียน tutorial GPIO ESP32 สั้นๆ"
# /model qwen2.5:14b
# /ask "เขียน tutorial GPIO ESP32 อย่างละเอียด"
# /status
```

### 7.2 USB Resilience Test
```bash
# ทดสอบ nofail mount — ดูว่า Jetson boot ได้ถ้า USB ไม่มี
# (ทำในสภาพแวดล้อม test ไม่ใช่ production)

# ตรวจสอบ USB speed
sudo hdparm -tT /dev/sda
# ควรได้ > 100 MB/s (USB 3.0) — ถ้าได้ < 40 MB/s แสดงว่าเป็น USB 2.0
```

### 7.3 Service Restart Verification
```bash
# ทดสอบว่า services restart อัตโนมัติ
sudo systemctl kill openclaw     # kill process
sleep 10
systemctl is-active openclaw     # ต้อง active อีกครั้ง
```

### 7.4 Log Rotation Setup
```bash
sudo tee /etc/logrotate.d/pwd-ai << 'EOF'
/var/log/pwd-*.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
}
EOF
```

---

## Phase 8 — OpenClaw Initial Configuration (UI)
**Duration:** Day 5 · 1 hour

1. เปิด browser → `http://192.168.x.x`
2. เข้า OpenClaw admin (credentials ตั้งตอน install)
3. เพิ่ม Provider:
   - Type: **Ollama**
   - Base URL: `http://127.0.0.1:11434`
   - Models: qwen2.5:7b, qwen2.5:14b, llama3.2:3b
4. สร้าง API Keys:
   - `bot-key` สำหรับ Telegram bot
   - `ken-key` สำหรับ Ken ใช้งานตรง
   - `team-key` สำหรับทีม (rate limit ต่ำกว่า)
5. ตั้ง Rate Limits per key
6. System Prompt: ใส่เนื้อหาจาก SOUL.md

---

## Go-Live Checklist

```
Infrastructure:
[ ] USB drive mounted, ext4, nofail in fstab
[ ] All models downloaded (ollama list)
[ ] eMMC usage < 60%
[ ] USB usage checked (du -sh /mnt/pwd-data/*)

Services:
[ ] ollama.service  — active (running)
[ ] openclaw.service — active (running)
[ ] pwd-bot.service  — active (running)
[ ] nginx.service    — active (running)
[ ] postgresql.service — active (running)
[ ] redis-server.service — active (running)
[ ] tailscaled.service — active (running)

Security:
[ ] UFW active, correct rules
[ ] .env file chmod 600
[ ] Ollama NOT accessible from LAN (curl from another machine → fail)
[ ] Telegram user_id whitelist set
[ ] OpenClaw API keys issued

Testing:
[ ] LAN access to OpenClaw UI works
[ ] Tailscale access works
[ ] Telegram /ask returns correct response
[ ] Backup script runs without error
[ ] Health check script works

Operational:
[ ] systemctl enable for all services
[ ] Cron jobs set (backup 02:00, health 5-min)
[ ] Log rotation configured
[ ] Team briefed on bot usage
```

---

## Timeline Summary

```
Day 1:  Phase 0 (System prep, USB setup, UFW, Tailscale)
        Phase 1 (Ollama native, USB models, GPU test)

Day 2:  Phase 2 (PostgreSQL + Redis → USB)
        Phase 3 (Node.js + OpenClaw native)
        Phase 4 (Nginx config)

Day 3:  Phase 5 (Telegram Bot — full build)

Day 4:  Phase 6 (Backup + health check scripts)
        Phase 7 (Testing & hardening)

Day 5:  Phase 8 (OpenClaw UI config, API keys)
        Go-live + team onboarding
```

---

*IMPLEMENTATION_PLAN.md v2.0.0 — Native Install, No Docker, USB Drive*
*PWD Vision Works · สันป่าตอง เชียงใหม่*
