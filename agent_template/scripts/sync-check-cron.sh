#!/usr/bin/env bash
# ============================================================
# sync-check-cron.sh — D1 Cloudflare ↔ Odoo Sync Verifier
# Path: /opt/pwd-ai/scripts/sync-check-cron.sh
# Crontab: 0 6 * * * /opt/pwd-ai/scripts/sync-check-cron.sh
# Description: ตรวจสอบ diff ระหว่าง D1 database กับ Odoo ERP
#              ส่งรายงานผ่าน Telegram — ต้อง Ken อนุมัติก่อน sync
# ============================================================

set -euo pipefail

DATE=$(date +%Y-%m-%d)
LOG_DIR="/var/log/pwd-ai"
REPORT_DIR="/mnt/pwd-data/reports/sync"
LOG_FILE="${LOG_DIR}/sync-check-${DATE}.log"
OPENCLAW_URL="http://127.0.0.1:18789"
APPROVE_URL="https://pwd.bs4u-tech.com/api/sync/approve"

mkdir -p "${LOG_DIR}" "${REPORT_DIR}"

log() { echo "[$(date +%Y-%m-%dT%H:%M:%S)] [sync-check] [$1] $2" | tee -a "${LOG_FILE}"; }

send_telegram() {
    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TG_CHAT_ID}" \
        -d parse_mode="HTML" \
        -d text="$1" >> "${LOG_FILE}" 2>&1
}

send_telegram_file() {
    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendDocument" \
        -F chat_id="${TG_CHAT_ID}" \
        -F document="@$1" \
        -F caption="$2" >> "${LOG_FILE}" 2>&1
}

log "INFO" "=== Starting Sync Check ${DATE} ==="

# --- Step 1: Fetch Odoo Products ---
log "INFO" "Fetching products from Odoo..."

ODOO_DATA_FILE="${REPORT_DIR}/odoo_products_${DATE}.json"

python3 << 'PYTHON_EOF' > "${ODOO_DATA_FILE}"
import xmlrpc.client
import json
import os

ODOO_URL = os.environ.get('ODOO_URL', 'https://pwdvisionworks.odoo.com')
ODOO_DB = os.environ.get('ODOO_DB', 'pwdvisionworks')
ODOO_USER = os.environ.get('ODOO_USER', '')
ODOO_PASS = os.environ.get('ODOO_PASS', '')

common = xmlrpc.client.ServerProxy(f'{ODOO_URL}/xmlrpc/2/common')
uid = common.authenticate(ODOO_DB, ODOO_USER, ODOO_PASS, {})

models = xmlrpc.client.ServerProxy(f'{ODOO_URL}/xmlrpc/2/object')

products = models.execute_kw(ODOO_DB, uid, ODOO_PASS,
    'product.template', 'search_read',
    [[['active', '=', True], ['website_published', '=', True]]],
    {
        'fields': ['name', 'default_code', 'list_price', 'qty_available',
                   'active', 'website_published', 'website_slug'],
        'limit': 200
    })

print(json.dumps({
    'source': 'odoo',
    'fetched_at': __import__('datetime').datetime.now().isoformat(),
    'count': len(products),
    'products': products
}, ensure_ascii=False, indent=2))
PYTHON_EOF

log "INFO" "Odoo data fetched: $(python3 -c "import json; d=json.load(open('${ODOO_DATA_FILE}')); print(d['count'])" 2>/dev/null || echo 'unknown') products"

# --- Step 2: Fetch D1 Cloudflare Products ---
log "INFO" "Fetching products from Cloudflare D1..."

D1_DATA_FILE="${REPORT_DIR}/d1_products_${DATE}.json"

curl -s -X POST \
    "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/d1/database/${CF_D1_DATABASE}/query" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"sql": "SELECT sku, name, price, stock_qty, status, updated_at FROM products WHERE status = '\''active'\'' ORDER BY sku"}' \
    > "${D1_DATA_FILE}" 2>>"${LOG_FILE}"

log "INFO" "D1 data fetched"

# --- Step 3: Compare and Generate Diff ---
log "INFO" "Running sync-verifier agent..."

DIFF_FILE="${REPORT_DIR}/sync_diff_${DATE}.json"

OPENCLAW_RESPONSE=$(curl -s -X POST "${OPENCLAW_URL}/api/agents/sync-verifier/run" \
    -H "Content-Type: application/json" \
    -d "{
        \"odoo_data\": $(cat ${ODOO_DATA_FILE} | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)))'),
        \"d1_data\": $(cat ${D1_DATA_FILE} | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)))'),
        \"context\": { \"date\": \"${DATE}\", \"auto_approve\": false }
    }" 2>>"${LOG_FILE}")

echo "${OPENCLAW_RESPONSE}" > "${DIFF_FILE}"

# --- Step 4: Parse results and send report ---
ISSUE_COUNT=$(python3 -c "
import json, sys
try:
    d = json.load(open('${DIFF_FILE}'))
    issues = d.get('output', {}).get('issues', [])
    print(len(issues))
except:
    print('unknown')
" 2>/dev/null)

CRITICAL_COUNT=$(python3 -c "
import json
try:
    d = json.load(open('${DIFF_FILE}'))
    issues = d.get('output', {}).get('issues', [])
    print(len([i for i in issues if i.get('severity') == 'critical']))
except:
    print(0)
" 2>/dev/null)

log "INFO" "Diff complete: ${ISSUE_COUNT} issues found (${CRITICAL_COUNT} critical)"

# Build Telegram message
if [[ "${ISSUE_COUNT}" == "0" ]]; then
    MESSAGE="✅ <b>PWD Sync Check</b> — ${DATE}
🔄 D1 ↔ Odoo: ปกติทุกรายการ
📦 ไม่มี issue ที่ต้องจัดการ
⏰ ตรวจสอบครั้งถัดไป: พรุ่งนี้ 06:00"
    send_telegram "${MESSAGE}"
else
    # Send summary
    MESSAGE="⚠️ <b>PWD Sync Check</b> — ${DATE}
🔴 Critical issues: ${CRITICAL_COUNT}
🟡 Total issues: ${ISSUE_COUNT}

📋 รายงานเต็มแนบมาในไฟล์
⚠️ <b>กรุณาตรวจสอบและ approve ก่อน sync</b>
🔗 Approve URL: ${APPROVE_URL}"
    send_telegram "${MESSAGE}"

    # Send detailed report as file if more than 5 issues
    if [[ "${ISSUE_COUNT}" -gt 5 ]] 2>/dev/null; then
        send_telegram_file "${DIFF_FILE}" "Sync diff report ${DATE}"
    else
        # Send inline for small number of issues
        INLINE_ISSUES=$(python3 -c "
import json
try:
    d = json.load(open('${DIFF_FILE}'))
    issues = d.get('output', {}).get('issues', [])
    lines = []
    for i in issues[:10]:
        severity = '🔴' if i.get('severity') == 'critical' else '🟡'
        lines.append(f\"{severity} {i.get('sku','?')} | {i.get('field','?')}: D1={i.get('d1_value','?')} vs Odoo={i.get('odoo_value','?')}\")
    print('\n'.join(lines))
except Exception as e:
    print(f'Error parsing: {e}')
" 2>/dev/null)
        send_telegram "📋 <b>Issue Details:</b>\n${INLINE_ISSUES}"
    fi
fi

log "INFO" "=== Sync Check Complete ==="
