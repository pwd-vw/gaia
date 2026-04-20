#!/usr/bin/env bash
# ============================================================
# daily-seo-cron.sh — PWD Vision Works Daily SEO Report
# Path: /opt/pwd-ai/scripts/daily-seo-cron.sh
# Crontab: 0 7 * * * /opt/pwd-ai/scripts/daily-seo-cron.sh
# Description: ดึงข้อมูล GSC → วิเคราะห์ด้วย OpenClaw → ส่ง Telegram
# ============================================================

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/pwd-ai"
REPORT_DIR="/mnt/pwd-data/reports/seo"
DATE=$(date +%Y-%m-%d)
DATETIME=$(date +%Y-%m-%d_%H%M%S)
LOG_FILE="${LOG_DIR}/daily-seo-${DATE}.log"
OPENCLAW_URL="http://127.0.0.1:18789"

# GSC Config
GSC_CREDENTIALS="/opt/pwd-ai/.credentials/gsc-service-account.json"
GSC_SITES=(
    "https://www.pwdvisionworks.com/"
    "https://bs4u-tech.com/"
)

# Telegram
TG_BOT_TOKEN="${TG_BOT_TOKEN:-}"
TG_CHAT_ID="${TG_CHAT_ID:-}"

# Date range (GSC has 2-3 day delay)
DATE_END=$(date -d "2 days ago" +%Y-%m-%d)
DATE_START=$(date -d "9 days ago" +%Y-%m-%d)
DATE_PREV_END=$(date -d "9 days ago" +%Y-%m-%d)
DATE_PREV_START=$(date -d "16 days ago" +%Y-%m-%d)

# --- Setup ---
mkdir -p "${LOG_DIR}" "${REPORT_DIR}"

log() {
    echo "[$(date +%Y-%m-%dT%H:%M:%S)] [daily-seo] [$1] $2" | tee -a "${LOG_FILE}"
}

send_telegram() {
    local message="$1"
    if [[ -z "${TG_BOT_TOKEN}" || -z "${TG_CHAT_ID}" ]]; then
        log "WARN" "Telegram credentials not set — skipping send"
        return 0
    fi
    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TG_CHAT_ID}" \
        -d parse_mode="HTML" \
        -d text="${message}" \
        >> "${LOG_FILE}" 2>&1
}

send_telegram_file() {
    local file_path="$1"
    local caption="$2"
    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendDocument" \
        -F chat_id="${TG_CHAT_ID}" \
        -F document="@${file_path}" \
        -F caption="${caption}" \
        >> "${LOG_FILE}" 2>&1
}

# --- Step 1: Fetch GSC Data ---
log "INFO" "=== Starting Daily SEO Report for ${DATE} ==="
log "INFO" "Fetching GSC data: ${DATE_START} to ${DATE_END}"

GSC_OUTPUT_FILE="${REPORT_DIR}/gsc_raw_${DATE}.json"

python3 << 'PYTHON_EOF' > "${GSC_OUTPUT_FILE}"
import json
import sys
import os
from datetime import datetime, timedelta
from google.oauth2 import service_account
from googleapiclient.discovery import build

DATE_END = (datetime.now() - timedelta(days=2)).strftime('%Y-%m-%d')
DATE_START = (datetime.now() - timedelta(days=9)).strftime('%Y-%m-%d')
DATE_PREV_END = (datetime.now() - timedelta(days=9)).strftime('%Y-%m-%d')
DATE_PREV_START = (datetime.now() - timedelta(days=16)).strftime('%Y-%m-%d')

CREDENTIALS_FILE = "/opt/pwd-ai/.credentials/gsc-service-account.json"
SITES = [
    "https://www.pwdvisionworks.com/",
    "https://bs4u-tech.com/"
]

SCOPES = ['https://www.googleapis.com/auth/webmasters.readonly']
credentials = service_account.Credentials.from_service_account_file(
    CREDENTIALS_FILE, scopes=SCOPES)
service = build('searchconsole', 'v1', credentials=credentials)

results = {}
for site in SITES:
    site_data = {}

    # Current period
    request = {
        'startDate': DATE_START,
        'endDate': DATE_END,
        'dimensions': ['page'],
        'rowLimit': 50,
        'dataState': 'final'
    }
    response = service.searchanalytics().query(
        siteUrl=site, body=request).execute()
    site_data['current_pages'] = response.get('rows', [])

    # Top queries
    request['dimensions'] = ['query']
    response = service.searchanalytics().query(
        siteUrl=site, body=request).execute()
    site_data['top_queries'] = response.get('rows', [])[:10]

    # Previous period for comparison
    request['startDate'] = DATE_PREV_START
    request['endDate'] = DATE_PREV_END
    request['dimensions'] = ['page']
    response = service.searchanalytics().query(
        siteUrl=site, body=request).execute()
    site_data['prev_pages'] = response.get('rows', [])

    # Site totals (current)
    request['startDate'] = DATE_START
    request['endDate'] = DATE_END
    request['dimensions'] = []
    response = service.searchanalytics().query(
        siteUrl=site, body=request).execute()
    site_data['totals'] = response.get('rows', [{}])[0] if response.get('rows') else {}

    results[site] = site_data

print(json.dumps({
    'date_range': {'start': DATE_START, 'end': DATE_END},
    'prev_range': {'start': DATE_PREV_START, 'end': DATE_PREV_END},
    'generated_at': datetime.now().isoformat(),
    'sites': results
}, ensure_ascii=False, indent=2))
PYTHON_EOF

if [[ $? -ne 0 ]]; then
    log "ERROR" "GSC fetch failed"
    send_telegram "⚠️ <b>PWD SEO Report</b>\n❌ GSC data fetch failed on ${DATE}\nCheck: ${LOG_FILE}"
    exit 1
fi

log "INFO" "GSC data fetched successfully → ${GSC_OUTPUT_FILE}"

# --- Step 2: Analyze with OpenClaw ---
log "INFO" "Sending to OpenClaw seo-auditor agent..."

GSC_DATA=$(cat "${GSC_OUTPUT_FILE}")
ANALYSIS_FILE="${REPORT_DIR}/analysis_${DATE}.json"

OPENCLAW_RESPONSE=$(curl -s -X POST "${OPENCLAW_URL}/api/agents/seo-auditor/run" \
    -H "Content-Type: application/json" \
    -d "{
        \"input\": $(echo "${GSC_DATA}" | jq -R -s '.'),
        \"context\": {
            \"date\": \"${DATE}\",
            \"report_type\": \"daily_seo\"
        }
    }" 2>>"${LOG_FILE}")

echo "${OPENCLAW_RESPONSE}" > "${ANALYSIS_FILE}"

if [[ $? -ne 0 ]]; then
    log "ERROR" "OpenClaw analysis failed"
    # Fallback: send raw summary
    TOTAL_IMPRESSIONS=$(cat "${GSC_OUTPUT_FILE}" | python3 -c "
import json,sys
d=json.load(sys.stdin)
total=0
for s in d['sites'].values():
    t=s.get('totals',{})
    total+=t.get('impressions',0)
print(int(total))
")
    send_telegram "📊 <b>PWD SEO Daily (raw)</b> - ${DATE}\nImpressions: ${TOTAL_IMPRESSIONS}\n⚠️ AI analysis unavailable"
    exit 1
fi

log "INFO" "Analysis complete → ${ANALYSIS_FILE}"

# --- Step 3: Format and Send Telegram Report ---
log "INFO" "Formatting Telegram report..."

TELEGRAM_MESSAGE=$(cat "${ANALYSIS_FILE}" | python3 -c "
import json, sys

data = json.load(sys.stdin)
report = data.get('output', data.get('message', 'No output'))

# Truncate if too long for Telegram (4096 char limit)
if len(report) > 4000:
    report = report[:3900] + '\n\n... [ดูรายงานเต็มใน /mnt/pwd-data/reports/seo/]'

print(report)
" 2>/dev/null || echo "📊 SEO Report ready — see ${ANALYSIS_FILE}")

send_telegram "${TELEGRAM_MESSAGE}"
log "INFO" "Telegram report sent"

# --- Step 4: Cleanup & Archive ---
# Keep last 30 days of reports
find "${REPORT_DIR}" -name "*.json" -mtime +30 -delete
log "INFO" "Cleanup complete"

log "INFO" "=== Daily SEO Report Complete ==="
echo "✅ SEO report complete: ${DATE}" | tee -a "${LOG_FILE}"
