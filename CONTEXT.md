# 📍 CONTEXT.md — Project Context & Living State
## PWD Vision Works AI Stack

**Version:** 3.2.0
**Last Updated:** 2026-04-20
**Updated by:** Ken (Owner) + Claude Sonnet (DEBUGGER)
**Purpose:** ให้ AI agent ทุก session เข้าใจสถานะปัจจุบันของ project ก่อนเริ่มทำงาน

> ⚠️ **AI AGENTS:** อ่านไฟล์นี้ก่อนทำงานทุกครั้ง
> ✏️ **AI AGENTS:** อัพเดตไฟล์นี้เมื่อทำงานสำเร็จหรือค้นพบข้อมูลสำคัญ

---

## 1. Current System State

### 1.1 Infrastructure Status

| Component | Status | Notes |
|-----------|--------|-------|
| Jetson AGX Xavier | 🟢 Done | JetPack 5.1.3 (R35 rev 6.4), MAXN mode, GPU 1,377 MHz (locked) |
| UFW Firewall | 🟢 Done | active — allow 22,80,443/tcp, 41641/udp; IPv6=no (Jetson kernel) |
| Tailscale | 🟢 Done | IP: 100.100.137.9, domain: ubuntu.tailce8ebd.ts.net |
| MicroSD Card Setup | 🟢 Done | /dev/mmcblk1p1 → /mnt/pwd-data (59G, 41% used, 33G free) |
| USB Drive | 🟢 Cold backup | /dev/sda1 — ไม่ mount อัตโนมัติ, UUID=9ca0a315... |
| Ollama (native ARM64) | 🟢 Done | v0.21.0, OLLAMA_HOST=127.0.0.1 ✅, models on MicroSD |
| PostgreSQL (MicroSD) | 🟢 Done | v12, data=/mnt/pwd-data/postgres/12/main, port 5432 |
| Redis (MicroSD) | 🟢 Done | v5.0.7, dir=/mnt/pwd-data/redis, port 6379 |
| Node.js via nvm | 🟢 Done | v24.15.0, symlinks /usr/local/bin/node + npm |
| OpenClaw gateway | 🟢 Done | v2026.4.15, port 18789 loopback, running as process |
| OpenClaw systemd | 🟢 Done | openclaw-gateway.service (user unit), enabled, Linger=yes |
| Telegram channel | 🟢 Done | เชื่อมต่อแล้ว, bot token set, group + user configured |
| Nginx | 🟢 Done | nginx 1.18.0, proxy → 18789, WebSocket support, rate limit |
| Backup scripts | 🟡 To Create | Phase 6 |

**Legend:** 🟢 Done · 🟡 In Progress / Planned · 🔴 Blocked · ⭕ Skipped

---

### 1.2 Architecture: Native Install (No Docker)

> **DECISION (2026-04-19):** Switched from Docker to native install.  
> Reason: eMMC storage is ~32 GB — too limited for Docker + images + OS.  
> Docker daemon alone uses 2–3 GB before any images are pulled.

**Runtime:** All services run as native systemd units — no container runtime.

### 1.3 Storage Architecture

| Location | Device | Size | What's stored |
|----------|--------|------|--------------|
| eMMC (internal) | `/dev/mmcblk0p1` | 28 GB | Ubuntu OS, JetPack, CUDA, binaries, app code, configs |
| **MicroSD Card** `/mnt/pwd-data` | `/dev/mmcblk1p1` | **59.5 GB** | Ollama models, PostgreSQL data, Redis dumps, backups |
| USB Drive (cold backup) | `/dev/sda1` | 28.9 GB | Emergency backup — ไม่ mount อัตโนมัติ |

> ❗ **Critical:** ต้อง reformat MicroSD จาก exFAT → ext4 ก่อนใช้งาน  
> ❗ **Critical:** Never pull Ollama models without `OLLAMA_MODELS=/mnt/pwd-data/ollama/models` env set.

### 1.4 Network Configuration
```
Jetson LAN IP:         192.168.1.177
Jetson Tailscale IP:   100.100.137.9
Tailscale hostname:    ubuntu.tailce8ebd.ts.net
OpenClaw gateway:      http://127.0.0.1:18789     (loopback only — bind=loopback)
OpenClaw Tailscale:    https://ubuntu.tailce8ebd.ts.net  (Tailscale serve configured)
OpenClaw LAN (Nginx):  http://192.168.1.177/      ✅ Phase 4 DONE
Gateway token:         fdd64994cc5eb2bd9e9eea275f7c4ffbd3bc64ce...  (ใน openclaw.json)
USB Device (backup):   /dev/sda1
USB UUID:              9ca0a315-98e9-4164-8858-1972488c659c
SSH alias (Mac):       ssh agx  (key: ~/.ssh/id_ed25519_agx)
```

### 1.5 Models (on MicroSD — Actual)

**Ollama models** (ใช้ผ่าน `ollama/` prefix ใน OpenClaw):
```
Model                    Size    ctx_window  Status       Speed (warm)   Use in OpenClaw
────────────────────────────────────────────────────────────────────────────────────────────
llama3.2:3b-32k          2.0 GB  32768       🟢 OK        26.2 tok/s     ollama/llama3.2:3b-32k ← DEFAULT
gemma4:latest            9.6 GB  131072      🟡 Slow      ~3-5 tok/s     ollama/gemma4:latest (heavy tasks)
qwen3.5:4b-fast          3.4 GB  16384       🟡 EN only   15+ tok/s      ollama/qwen3.5:4b-fast (custom, EN only)
qwen3.5:4b               3.4 GB  32768       🔴 Timeout   —              อย่าใช้ (Thinking mode timeout)
qwen3.5:latest           6.6 GB  32768       🔴 OOM       —              อย่าใช้ (crash)

MicroSD total: ~25 GB / 59 GB (42% — เหลือ ~31 GB ✅)
```

> ⚠️ **qwen3.5 THINKING MODE WARNING:** Qwen3.5 มี thinking mode enabled by default  
> → สร้าง chain-of-thought tokens (empty response) นานถึง 60-250 วินาที ก่อนตอบจริง  
> → KvSize ถูก force เป็น 32768 (262K context) → ใช้ RAM 13+ GB  
> → Compute graph 6.5 GiB (llama3.2:3b ใช้แค่ 256 MiB)  
> **qwen3.5:4b-fast** ใช้ `/no_think` SYSTEM prompt — ทำงานได้เฉพาะ English เท่านั้น

> ⚠️ **OpenClaw contextWindow MINIMUM = 16,000:** ค่า `contextWindow` ใน models.providers.ollama.models  
> ต้องตั้ง ≥ 16000 เสมอ — ต่ำกว่านี้ OpenClaw reject model ทันที (ไม่ fallback, ไม่ retry)  
> ต้องสร้าง custom Modelfile (num_ctx) ให้ตรงกับ contextWindow ด้วย มิฉะนั้น Ollama truncate context โดยเงียบ

> ⚠️ **FlashAttention ไม่รองรับบน Volta/sm_72** — `OLLAMA_FLASH_ATTENTION=1` ไม่มีผล  
> Jetson AGX Xavier GPU = compute capability 7.2 — ต้องการ 8.0+ สำหรับ FlashAttention

**Cloud models** (configured ใน OpenClaw — ต้องใช้ API key):
```
google/gemini-2.0-flash       🟢 configured  (Google AI API key)
anthropic/claude-haiku-4-5    🟢 configured  (Anthropic API key)
```

**Default model ใน OpenClaw:** `ollama/llama3.2:3b-32k` ← Modelfile: num_ctx=32768, 26.2 tok/s (warm), Thai+EN

> ⚠️ **BUG FIXED (2026-04-19):** ต้องมี `models.providers.ollama` section ใน openclaw.json  
> แค่ตั้ง `OLLAMA_API_KEY` env var อย่างเดียวไม่พอ — ต้องมี `baseUrl`, `apiKey`, `models[]` ด้วย

---

## 2. Current Phase

**Active Phase:** Phase 6 — Backup Scripts
**Phase 0 Status:** ✅ Done — UFW active (IPv6=no), Tailscale active, MicroSD mounted
**Phase 1 Status:** ✅ Done — Ollama on MicroSD, OLLAMA_HOST=127.0.0.1, 3 models OK
**Phase 2 Status:** ✅ Done — PostgreSQL 12 + Redis 5 บน MicroSD, openclaw DB ready
**Phase 3 Status:** ✅ Done — OpenClaw v2026.4.15 + Telegram ✅ + openclaw-gateway.service ✅
**Phase 4 Status:** ✅ Done — Nginx 1.18.0, proxy 80 → 18789, WebSocket, rate-limit 30r/m
**Phase 5 Status:** ✅ Done — Telegram channel เชื่อมต่อแล้วผ่าน OpenClaw (ไม่ต้อง build แยก)
**Started:** 2026-04-19
**Next Action:**
1. Phase 6 — backup.sh + health-check.sh + cron jobs

---

## 3. Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-18 | Use Telegram Long Polling | No public IP needed for bot |
| 2026-04-18 | Nginx as reverse proxy | Single entry point, SSL, rate limiting |
| 2026-04-18 | OpenClaw as AI gateway | API key management, routing, rate limits |
| 2026-04-18 | qwen2.5 as primary model | Best Thai language support |
| 2026-04-19 | Native install — NO Docker | eMMC space constraint, ARM64 Docker issues, simpler GPU access |
| 2026-04-19 | USB Drive for large data | No NVMe available — USB 3.0 for models + DB |
| 2026-04-19 | nofail in fstab | Jetson must boot even if storage is unplugged |
| 2026-04-19 | OLLAMA_MODELS env override via systemd | Point models to external drive |
| 2026-04-19 | PostgreSQL PGDATA moved to external drive | DB data must not fill eMMC |
| **2026-04-19** | **USB Drive → MicroSD Card (mmcblk1)** | **USB 85% full (28.9 GB), MicroSD 59.5 GB ว่าง; mount point /mnt/pwd-data คงเดิม** |
| **2026-04-19** | **Reformat MicroSD exFAT → ext4** | **exFAT ไม่รองรับ chown/chmod — PostgreSQL, Redis ไม่ทำงาน** |
| **2026-04-19** | **USB drive เป็น cold backup** | **ไม่ format ทิ้ง — เก็บ data เดิมไว้เป็น fallback** |
| **2026-04-19** | **OpenClaw port 18789 (ไม่ใช่ 3000)** | **OpenClaw v2026.4.15 ใช้ port 18789, bind=loopback — ARCHITECTURE.md แก้ไขแล้ว** |
| **2026-04-19** | **ไม่มี pwd-bot.service — Telegram ผ่าน OpenClaw native** | **OpenClaw channels.telegram จัดการ polling เอง — ไม่ต้องสร้าง bot process แยก** |
| **2026-04-19** | **OpenClaw config อยู่ที่ ~/.openclaw/openclaw.json** | **ไม่ใช่ /opt/pwd-ai/openclaw/config.json — ใช้ JSON5 format, hot-reload ได้** |
| **2026-04-19** | **OpenClaw ไม่ใช้ PostgreSQL/Redis** | **OpenClaw ใช้ file-based state ใน ~/.openclaw/ เอง — DB ที่สร้างไว้ reserve สำหรับ future services** |
| **2026-04-19** | **Nginx ยังจำเป็น (Phase 4)** | **OpenClaw bind=loopback → LAN access ต้องผ่าน Nginx reverse proxy port 80 → 18789** |
| **2026-04-19** | **openclaw.service ต้องสร้างเป็น user systemd unit** | **ปัจจุบัน OpenClaw รัน bare process — crash แล้วไม่ restart; ต้องทำ `openclaw onboard` หรือสร้าง unit เอง** |
| **2026-04-19** | **PostgreSQL 12 (ไม่ใช่ 14)** | **Jetson Ubuntu 20.04 ติดตั้ง pg12 default — path /mnt/pwd-data/postgres/12/main** |

---

## 4. Open Questions & Blockers

```
[RESOLVED] JetPack version → R35 rev 6.4 = JetPack 5.1.3
[RESOLVED] Tailscale → installed, IP 100.100.137.9
[RESOLVED] BUG-01 UFW → active (IPv6=no ปิดเพราะ Jetson kernel ไม่รองรับ ip6tables rt)
[RESOLVED] BUG-02 OLLAMA_HOST → 127.0.0.1:11434 (ไม่เปิด LAN แล้ว)
[RESOLVED] BUG-03 USB เต็ม → migrate ไป MicroSD 59.5 GB (เหลือ 33 GB)
[RESOLVED] MicroSD UUID → 5916b017-1a73-451a-b757-43f0ec0eede4
[RESOLVED] OpenClaw install → global npm ผ่าน nvm (ติดตั้งก่อนหน้าแล้ว v2026.4.15)
[RESOLVED] Telegram → เชื่อมต่อแล้ว bot 8656460842, allowFrom: [8035099130]
[RESOLVED] Telegram group → -1003741432352 (requireMention: false)

[RESOLVED] openclaw-gateway.service — enabled, Restart=always, Linger=yes (boot auto-start)
[RESOLVED] Nginx Phase 4 — nginx 1.18.0 active, http://192.168.1.177 → 18789 ✅

[🟡 TODO] Phase 6 — backup.sh (cron 02:00) + health-check.sh (cron */5) 
[ ] MicroSD speed test — hdparm -tT /dev/mmcblk1 (ยังไม่ได้ทดสอบ)
[ ] OpenClaw PostgreSQL/Redis — ยังไม่ได้ connect (OpenClaw ใช้ file-based state เอง)
```

---

## 5. File Structure

### On eMMC (small files — code + configs)
```
~/.openclaw/                   ← OpenClaw runtime (installed via nvm global)
├── openclaw.json              ✅ configured — port 18789, Telegram, models
└── workspace/                 ✅ agent memory + sessions (file-based, NOT postgres)

/opt/pwd-ai/
├── scripts/backup.sh           🟡 Phase 6
├── scripts/health-check.sh    🟡 Phase 6
└── docs/
    ├── ARCHITECTURE.md        ✅ v2.2.0
    ├── IMPLEMENTATION_PLAN.md ✅ v2.0.0
    ├── AGENTS.md              ✅ v1.0.0
    ├── SOUL.md                ✅ v1.0.0
    ├── CONTEXT.md             ✅ v2.6.0 (this file)
    └── GUARDRAILS.md          ✅ v1.0.0
```

### On MicroSD (large data — /mnt/pwd-data)
```
/mnt/pwd-data/
├── ollama/models/             ✅ Phase 1 (gemma4, qwen3.5:4b, qwen3.5:latest)
├── postgres/12/main/          ✅ Phase 2 (DB: openclaw, user: openclaw)
├── redis/dump.rdb             ✅ Phase 2
└── backups/                   🟡 Phase 6
```

---

## 6. Known Technical Notes

### Ollama on Jetson (native)
- Official ARM64 binary: `curl -fsSL https://ollama.com/install.sh | sh`
- **Must** set `OLLAMA_MODELS=/mnt/pwd-data/ollama/models` before pulling any model
- GPU inference via CUDA Volta — `nvpmodel -m 0` + `jetson_clocks` for best performance
- `tegrastats` to monitor GPU memory during inference
- ⚠️ **`jetson_clocks` MUST be applied** — without it GPU stays at 114 MHz (8% of max 1,377 MHz)
- `jetson-clocks.service` (systemd) ensures this persists across reboots — ติดตั้งแล้ว
- `GR3D_FREQ %` ใน tegrastats = % ของ clock ปัจจุบัน ไม่ใช่ % ของ max — อย่าหลงเชื่อ
- `OLLAMA_NUM_PARALLEL=1` — Jetson unified memory ไม่พอสำหรับ parallel inference
- `OLLAMA_KEEP_ALIVE=-1` — **REQUIRED** — ป้องกัน model unload หลัง 5 นาที (default)
  - ไม่ตั้ง = model unload ทุก 5 นาที → cold start → idle watchdog timeout ใน OpenClaw
  - ตั้ง -1 = model stay loaded ตลอด (`expires_at` = year 2318)
  - ตั้งใน `/etc/systemd/system/ollama.service.d/override.conf`

### PostgreSQL USB
- After install, stop service, `rsync` data dir to USB, update `postgresql.conf data_directory`
- chown -R postgres:postgres on USB postgres directory

### USB Dependency in systemd
- Use `ConditionPathIsMountPoint=/mnt/pwd-data` in service units
- Use `After=mnt-pwd\x2ddata.mount` — systemd escapes `-` as `\x2d` in unit names
- `nofail` in /etc/fstab allows boot without USB

### Docker is NOT used
- No `docker`, `docker compose`, or Docker volumes anywhere in this stack
- If future AI sessions suggest Docker solutions — refer them to this CONTEXT.md decision

---

## 7. Use Cases (validate after setup)

| Use Case | Model | Result | Date |
|----------|-------|--------|------|
| PostgreSQL connection test | — | ✅ PASS — openclaw user TCP connect | 2026-04-19 |
| Redis ping test | — | ✅ PASS — PONG, dir on MicroSD | 2026-04-19 |
| SEO audit review (GSC data) | qwen3.5:4b | ✅ PASS — analysis ดี | 2026-04-19 |
| OpenClaw gateway running | — | ✅ PASS — openclaw-gateway.service, port 18789, Restart=always | 2026-04-19 |
| Telegram channel | — | ✅ PASS — connected, bot responding | 2026-04-19 |
| Nginx LAN access (HTTP) | — | ✅ PASS — http://192.168.1.177 → 200 OK | 2026-04-19 |
| Nginx Tailscale IP (HTTP) | — | ✅ PASS — http://100.100.137.9 → 200 OK | 2026-04-19 |
| OpenClaw Tailscale HTTPS | — | ✅ PASS — https://ubuntu.tailce8ebd.ts.net → 200 OK | 2026-04-19 |
| English chat (fast) | llama3.2:3b-32k | ✅ PASS — 26.2 tok/s (warm), Thai+EN OK | 2026-04-20 |
| Thai prompt | llama3.2:3b-32k | ✅ PASS — "ESP32 vs RPi" ตอบได้ 295 tokens | 2026-04-20 |
| English chat no-think | qwen3.5:4b-fast | ✅ PASS — 15.3 tok/s, 16.6s total | 2026-04-20 |
| Thai prompt | qwen3.5:4b-fast | 🔴 FAIL — Thinking mode active (>75s timeout) | 2026-04-20 |
| Thai prompt | qwen3.5:4b | 🔴 FAIL — Thinking mode (60-250s, always timeout) | 2026-04-20 |
| ESP32 GPIO tutorial (TH) | llama3.2:3b | 🟡 Pending | — |
| Odoo product description | llama3.2:3b | 🟡 Pending | — |
| Telegram /ask Q&A | llama3.2:3b | 🟡 Pending | — |
| Article writing (long) | gemma4:latest | 🟡 Pending — ยังไม่ทดสอบ | — |
| Heavy analysis | qwen3.5:latest | 🔴 OOM Crash | 2026-04-19 |

---

## 8. Environment Variables Reference

```bash
# OpenClaw config: ~/.openclaw/openclaw.json  (file-based, ไม่ใช้ .env)
# OpenClaw state:  ~/.openclaw/
# OpenClaw workspace: ~/.openclaw/workspace/
# Gateway port:    18789 (loopback)
# Gateway token:   ดูใน openclaw.json > gateway.auth.token

# Systemd drop-in — ~/.config/systemd/user/openclaw-gateway.service.d/ollama-env.conf
OLLAMA_API_KEY=ollama-local          # required — ต้องมีทุกครั้ง
NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache  # startup speed
OPENCLAW_NO_RESPAWN=1                # avoid extra startup overhead

# Systemd override — /etc/systemd/system/ollama.service.d/override.conf
OLLAMA_MODELS=/mnt/pwd-data/ollama/models
OLLAMA_HOST=127.0.0.1:11434
OLLAMA_NUM_PARALLEL=1
OLLAMA_KEEP_ALIVE=-1         # ห้ามลบ — ป้องกัน model unload (ทำให้ timeout ใน OpenClaw)

# PostgreSQL (Phase 2 — DONE, ใช้สำหรับ services อื่น ไม่ใช่ OpenClaw)
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=openclaw
DB_USER=openclaw
DB_PASS=pwd_openclaw_2026

# Redis (Phase 2 — DONE)
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASS=pwd_redis_2026
```

---

## 9. Contacts & Access

```
Jetson SSH (LAN):       ssh agx  (key ~/.ssh/id_ed25519_agx)
Jetson SSH (Tailscale): ssh agx-tail  (100.100.137.9)
OpenClaw gateway:       http://127.0.0.1:18789  (loopback)
OpenClaw (Tailscale):   https://ubuntu.tailce8ebd.ts.net
OpenClaw (LAN via Nginx): http://192.168.1.177  (Phase 4 — DONE ✅)
Telegram Bot:           @pwdcybi_ceo_bot (allowFrom: [8035099130])
Telegram Group:         -1003741432352 (requireMention: false)
```

---

## 10. Update Log

```
2026-04-18 | Ken + Claude Sonnet | v1.0.0 — Initial architecture (Docker-based)
                                  | All docs created: SOUL, AGENTS, GUARDRAILS, CONTEXT

2026-04-19 | Ken + Claude Sonnet | v2.0.0 — BREAKING CHANGE: Docker → Native Install
                                  | Reason: eMMC space constraint, no NVMe available
                                  | USB Drive adopted for all large data storage
                                  | ARCHITECTURE.md rewritten to v2.0.0
                                  | IMPLEMENTATION_PLAN.md rewritten to v2.0.0
                                  | CONTEXT.md updated to v2.0.0

2026-04-19 | Claude (TESTER)     | v2.1.0 — Phase 1 Test PASS + bugs discovered
                                  | Phase 1: ✅ PASS (Ollama, USB mount, API, eMMC)
                                  | BUG-01: UFW not active (Phase 0 incomplete)
                                  | BUG-02: OLLAMA_HOST=0.0.0.0 (security risk)
                                  | BUG-03: USB 85% full — เหลือ 4.3 GB
                                  | Resolved: JetPack 5.1.3, Tailscale IP, USB UUID
                                  | Updated: models list, network config, phase status

2026-04-19 | Claude (BUILDER)    | v2.5.0 — CONTEXT updated to reflect actual system state
                                  | Phase 3 + 5: OpenClaw v2026.4.15 already installed + configured
                                  | Telegram: @pwdcybi_ceo_bot connected, group -1003741432352
                                  | Models: gemma4 + qwen3.5:4b OK, qwen3.5:latest OOM
                                  | Cloud models: gemini-2.0-flash + claude-haiku-4-5 configured
                                  | Gateway: port 18789 loopback, Tailscale serve configured
                                  | Missing: openclaw systemd unit (auto-restart), Nginx Phase 4

2026-04-19 | Claude (BUILDER)    | v2.4.0 — Phase 2 complete: PostgreSQL 12 + Redis 5
                                  | PostgreSQL data_dir → /mnt/pwd-data/postgres/12/main
                                  | Redis dir → /mnt/pwd-data/redis, requirepass set
                                  | openclaw DB + user created, TCP connection verified
                                  | Both services: systemd enabled + MicroSD dependency

2026-04-19 | Claude (BUILDER)    | v2.3.0 — Storage migration executed + bugs fixed
                                  | MicroSD formatted ext4, rsync 23GB @79MB/s, fstab updated
                                  | BUG-01 FIXED: UFW active (IPv6=no, Jetson kernel limit)
                                  | BUG-02 FIXED: OLLAMA_HOST=127.0.0.1 (LAN port closed)
                                  | BUG-03 FIXED: /mnt/pwd-data now 59G MicroSD, 33G free
                                  | USB /dev/sda1 → cold backup (not auto-mounted)

2026-04-20 | Claude (DEBUGGER)  | v3.2.0 — BUG-FIX: OLLAMA_KEEP_ALIVE not set → cold start timeout
                                  | ROOT CAUSE: default keep-alive = 5m → model unloads
                                  |   → next Telegram msg hits cold start → idle watchdog fires
                                  | EVIDENCE: 14:59:40 llm-idle-timeout; `{"models":[]}` seen
                                  | PERF: warm model = TTFT 2.41s (1120-token prompt), 23.7 tok/s
                                  | FIX: OLLAMA_KEEP_ALIVE=-1 in override.conf
                                  |   → expires_at: year 2318 (permanent)
                                  | CLEANED: removed FLASH_ATTENTION=1 + KV_CACHE=q8_0 (no-ops)
                                  | TESTED: Thai response ✅ after Ollama restart
                                  | ANSWER: qwen3.5:4b ❌ (thinking), gemma4 ❌ (slower, bigger)
                                  |   llama3.2:3b-32k ✅ — ถูกต้อง ให้ fix keep-alive แทน

2026-04-20 | Claude (DEBUGGER)  | v3.1.0 — BUG-FIX: contextWindow too small (4096 < min 16000)
                                  | ROOT CAUSE: llama3.2:3b ถูกเพิ่มด้วย contextWindow=4096
                                  |   → OpenClaw hard minimum = 16000 → block model ทันที
                                  |   → qwen3.5:4b-fast contextWindow=8192 < 16000 → fix ด้วย
                                  | FIX: สร้าง Modelfile + rebuild ทั้งสองโมเดล
                                  |   → llama3.2:3b-32k: num_ctx=32768, contextWindow=32768
                                  |   → qwen3.5:4b-fast: num_ctx=16384, contextWindow=16384
                                  | RULE LEARNED: contextWindow ใน openclaw.json ต้อง ≥ 16000
                                  |   และต้องมี Modelfile กำหนด num_ctx ให้ตรงกันด้วย
                                  | TESTED: llama3.2:3b-32k Thai = 26.2 tok/s ✅
                                  | Hot-reload applied: default = ollama/llama3.2:3b-32k

2026-04-20 | Claude (TESTER)    | v3.0.0 — MODEL FIX: เปลี่ยน default เป็น llama3.2:3b
                                  | ROOT CAUSE (final): qwen3.5:4b Thinking Mode
                                  |   → KvSize forced 32768 (262K ctx) = 13.28 GB RAM
                                  |   → Compute graph 6.5 GiB vs 256 MiB (llama3.2)
                                  |   → Empty chain-of-thought tokens 60-250s ก่อนตอบ
                                  | MODEL ADDED: llama3.2:3b (10.67 tok/s ✅ Thai+EN)
                                  | MODEL ADDED: qwen3.5:4b-fast (15.3 tok/s EN only)
                                  |   → Custom Modelfile: num_ctx=8192, SYSTEM "/no_think"
                                  |   → Thai prompt ยังคง timeout (thinking mode active for Thai)
                                  | DEFAULT CHANGED: qwen3.5:4b → llama3.2:3b (openclaw.json)
                                  | Hot-reload confirmed: config applied without restart
                                  | HARDWARE: FlashAttention ไม่รองรับ Volta/sm_72 (CC 7.2)
                                  | HARDWARE: OLLAMA_FLASH_ATTENTION=1 + KV_CACHE_TYPE=q8_0 = no effect

2026-04-19 | Claude (DEBUGGER)   | v2.9.0 — BUG-FIX: GPU clock stuck at 114 MHz (8% of max)
                                  | ROOT CAUSE: jetson_clocks not applied after boot
                                  | FIX-01: sudo jetson_clocks → GPU 1,377 MHz (max) applied
                                  | FIX-02: jetson-clocks.service (systemd) → persistent on boot
                                  | FIX-03: primary model → ollama/qwen3.5:4b (safer default)
                                  | FIX-04: heartbeat.every → 5m (more margin for large models)
                                  | BEFORE: qwen3.5:4b = 14.9 tok/s (GPU at 114 MHz)
                                  | EXPECTED AFTER: ~60-90 tok/s (GPU at 1,377 MHz)
                                  | NOT the cause: MicroSD (IO=0%), network (WS latency fine)

2026-04-19 | Claude (DEBUGGER)   | v2.8.0 — BUG-FIX: OpenClaw Ollama auth + provider config
                                  | BUG-01 FIXED: Added models.providers.ollama to openclaw.json
                                  |   → baseUrl: http://127.0.0.1:11434, apiKey: ollama-local
                                  |   → models array: gemma4:latest, qwen3.5:4b, qwen3.5:latest
                                  | BUG-02 FIXED: gateway.trustedProxies: [127.0.0.1] for Nginx
                                  | OPTIMIZED: NODE_COMPILE_CACHE + OPENCLAW_NO_RESPAWN=1 in drop-in
                                  | VERIFIED: openclaw models list shows 5 models Auth:yes

2026-04-19 | Claude (BUILDER)    | v2.7.0 — Phase 3 completion + Phase 4 Nginx DONE
                                  | Phase 3: openclaw-gateway.service confirmed enabled+running
                                  | Phase 3: Linger=yes → auto-start at boot (no login needed)
                                  | Phase 4: nginx 1.18.0 installed, /etc/nginx/sites-available/pwd-ai
                                  | Phase 4: WebSocket support (Upgrade header passthrough)
                                  | Phase 4: rate-limit 30r/m, proxy_read_timeout 300s
                                  | Phase 4: allowedOrigins updated (192.168.1.177, 100.100.137.9)
                                  | TESTED: direct/LAN/Tailscale-IP/Tailscale-HTTPS all 200 OK
                                  | Next: Phase 6 backup.sh + health-check.sh

2026-04-19 | Claude (ARCHITECT)  | v2.6.0 — OpenClaw v2026.4.15 architecture corrections
                                  | ARCHITECTURE.md updated to v2.2.0
                                  | Fixed: port 3000→18789, removed pwd-bot.service
                                  | Fixed: postgres/14/→12/, config path ~/.openclaw/
                                  | Fixed: diagram (loopback, Telegram via OpenClaw native)
                                  | Decisions: OpenClaw file-based state, Nginx still needed
                                  | Todo: openclaw.service systemd unit (auto-restart)

2026-04-19 | Claude (ARCHITECT)  | v2.2.0 — Storage migration design: USB → MicroSD
                                  | Decision: mmcblk1p1 (59.5 GB) แทน sda1 (28.9 GB 85% full)
                                  | Decision: Reformat exFAT → ext4 (Linux permissions)
                                  | Decision: Mount point /mnt/pwd-data คงเดิม (zero config change)
                                  | Decision: USB drive เป็น cold backup
                                  | ARCHITECTURE.md updated to v2.1.0
```

---

*CONTEXT.md v3.2.0 — Living Document — อัพเดตทุกครั้งที่ project state เปลี่ยน*
*PWD Vision Works · สันป่าตอง เชียงใหม่*
