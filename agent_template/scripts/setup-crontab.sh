#!/usr/bin/env bash
# ============================================================
# setup-crontab.sh — ติดตั้ง cron jobs และ environment
# Path: /opt/pwd-ai/scripts/setup-crontab.sh
# รันครั้งเดียวตอน initial setup
# ============================================================

set -euo pipefail
echo "=== PWD Vision Works — OpenClaw Setup ==="

# --- 1. Create directory structure ---
echo "📁 Creating directories..."
mkdir -p /opt/pwd-ai/{docs,scripts,templates,.credentials}
mkdir -p /var/log/pwd-ai
mkdir -p /mnt/pwd-data/reports/{seo,sync}
mkdir -p /mnt/pwd-data/openclaw/{workspace,cache}

# --- 2. Set permissions ---
chmod 700 /opt/pwd-ai/.credentials
chmod 755 /opt/pwd-ai/scripts/*.sh

# --- 3. Create .env template ---
echo "🔐 Creating .env template..."
cat > /opt/pwd-ai/.env.template << 'ENV_EOF'
# PWD Vision Works — OpenClaw Environment Variables
# Copy this to /opt/pwd-ai/.env and fill in values
# NEVER commit .env to git

# Telegram
TG_BOT_TOKEN=
TG_OWNER_USER_ID=       # Ken's Telegram user ID (number)
TG_REPORT_CHAT_ID=      # Chat ID for reports (Ken's personal or group)

# Odoo ERP
ODOO_URL=https://pwdvisionworks.odoo.com
ODOO_DB=pwdvisionworks
ODOO_USER=
ODOO_PASS=

# Cloudflare D1
CF_ACCOUNT_ID=
CF_API_TOKEN=
CF_D1_DATABASE=pwd-products

# Google Search Console
# กรุณาดาวน์โหลด service account JSON จาก Google Cloud Console
# แล้ว save ไว้ที่ /opt/pwd-ai/.credentials/gsc-service-account.json
# แล้วเพิ่ม service account email ใน GSC property settings

# PWD Sync API
SYNC_API_URL=https://pwd.bs4u-tech.com/api
SYNC_API_KEY=
ENV_EOF

if [[ ! -f /opt/pwd-ai/.env ]]; then
    cp /opt/pwd-ai/.env.template /opt/pwd-ai/.env
    chmod 600 /opt/pwd-ai/.env
    echo "⚠️  กรุณาแก้ไข /opt/pwd-ai/.env ใส่ค่าที่ถูกต้องก่อนรัน agents"
else
    echo "✅ .env already exists — skipping"
fi

# --- 4. Install Python dependencies ---
echo "🐍 Installing Python dependencies..."
pip3 install --break-system-packages \
    google-auth \
    google-auth-httplib2 \
    google-api-python-client \
    requests \
    python-dotenv \
    2>/dev/null || echo "⚠️ Some packages may have failed — check manually"

# --- 5. Install crontab ---
echo "⏰ Installing cron jobs..."

CRONTAB_CONTENT=$(crontab -l 2>/dev/null || echo "")

install_cron() {
    local cron_line="$1"
    local description="$2"
    if echo "${CRONTAB_CONTENT}" | grep -qF "$3"; then
        echo "  ✅ Already installed: ${description}"
    else
        CRONTAB_CONTENT="${CRONTAB_CONTENT}
${cron_line}"
        echo "  ➕ Added: ${description}"
    fi
}

# SEO Daily Report — 07:00 ทุกวัน
install_cron \
    "0 7 * * * /bin/bash /opt/pwd-ai/scripts/daily-seo-cron.sh >> /var/log/pwd-ai/cron-seo.log 2>&1" \
    "Daily SEO Report (07:00)" \
    "daily-seo-cron.sh"

# Sync Check — 06:00 ทุกวัน
install_cron \
    "0 6 * * * /bin/bash /opt/pwd-ai/scripts/sync-check-cron.sh >> /var/log/pwd-ai/cron-sync.log 2>&1" \
    "D1↔Odoo Sync Check (06:00)" \
    "sync-check-cron.sh"

# Log rotation — 02:00 ทุกวัน
install_cron \
    "0 2 * * * find /var/log/pwd-ai -name '*.log' -mtime +30 -delete 2>/dev/null" \
    "Log cleanup (02:00)" \
    "pwd-ai.*-mtime"

# Report archive — 03:00 ทุกวัน
install_cron \
    "0 3 * * * find /mnt/pwd-data/reports -name '*.json' -mtime +30 -delete 2>/dev/null" \
    "Report cleanup (03:00)" \
    "pwd-data/reports.*-mtime"

echo "${CRONTAB_CONTENT}" | crontab -
echo "✅ Crontab installed"

# --- 6. Verify cron installation ---
echo ""
echo "=== Current Crontab ==="
crontab -l | grep -E "(pwd-ai|daily-seo|sync-check)" || echo "(none found)"

# --- 7. Create logrotate config ---
echo ""
echo "📋 Setting up logrotate..."
cat > /etc/logrotate.d/pwd-ai << 'LOGROTATE_EOF'
/var/log/pwd-ai/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
LOGROTATE_EOF

# --- 8. Copy docs to /opt/pwd-ai ---
echo "📄 Copying docs..."
cp -r /home/claude/openclaw-pwd/docs/* /opt/pwd-ai/docs/ 2>/dev/null || true
cp -r /home/claude/openclaw-pwd/templates/* /opt/pwd-ai/templates/ 2>/dev/null || true
cp -r /home/claude/openclaw-pwd/scripts/* /opt/pwd-ai/scripts/ 2>/dev/null || true
chmod +x /opt/pwd-ai/scripts/*.sh

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "NEXT STEPS:"
echo "1. แก้ไข /opt/pwd-ai/.env — ใส่ API keys ทั้งหมด"
echo "2. วาง GSC service account JSON ที่ /opt/pwd-ai/.credentials/gsc-service-account.json"
echo "3. คัดลอก openclaw.json ไปที่ ~/.openclaw/openclaw.json"
echo "4. รัน: openclaw restart"
echo "5. ทดสอบ: curl http://127.0.0.1:18789/api/health"
echo "6. ทดสอบ SEO agent: curl -X POST http://127.0.0.1:18789/api/agents/seo-auditor/run"
echo ""
echo "TELEGRAM COMMANDS (หลัง setup):"
echo "  /seo        → รัน SEO report ทันที"
echo "  /sync       → ตรวจสอบ D1↔Odoo"
echo "  /status     → ตรวจสอบ system health"
echo ""
