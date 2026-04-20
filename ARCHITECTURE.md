# 🏗️ PWD Vision Works — AI Stack Architecture Blueprint
## Jetson AGX Xavier · Native Install (No Docker) · USB Drive Storage

**Version:** 2.2.0
**Updated:** 2026-04-19
**Previous:** v2.1.0 (stale OpenClaw port/path references — superseded)
**Owner:** PWD Vision Works (San Pa Tong, Chiang Mai)
**Hardware:** NVIDIA Jetson AGX Xavier · 32 GB Unified Memory · eMMC + MicroSD Card

---

## 1. Overview & Design Philosophy

> "One box. Native performance. No container overhead."

**Why native over Docker:**
- eMMC internal storage is limited (~32 GB total)
- Ollama GPU access is simpler native
- ARM64 — native binaries are always ARM64
- Native systemd services are more transparent, easier to debug, and restart faster
- MicroSD mounts as a plain filesystem path — no volume-mapping abstraction needed

**Storage Strategy:**
```
Internal eMMC (~28 GB):   OS + JetPack + CUDA + binaries + app code + configs
MicroSD Card (59.5 GB):   Ollama models + PostgreSQL data + Redis dumps + backups
USB Drive (28.9 GB):      Cold backup / emergency storage (ไม่ใช้เป็น primary)
```

> **DECISION (2026-04-19):** เปลี่ยนจาก USB Drive → MicroSD Card  
> Reason: USB เต็ม 85% (28.9 GB ไม่พอ), MicroSD 59.5 GB ให้พื้นที่เพียงพอ  
> Mount point `/mnt/pwd-data` คงเดิม — service configs ไม่ต้องแก้ไข

---

## 2. Hardware Profile

| Component | Actual |
|-----------|--------|
| SoC | NVIDIA Jetson AGX Xavier |
| CPU | 8-core ARM Carmel v8.2 @ 2.265 GHz |
| GPU | 512-core Volta + 64 Tensor Cores |
| Unified Memory | 32 GB LPDDR4x |
| Internal eMMC | 28 GB (`/dev/mmcblk0p1` → `/`) |
| **MicroSD Card** | **59.5 GB (`/dev/mmcblk1p1` → `/mnt/pwd-data`) ← PRIMARY** |
| USB Drive | 28.9 GB (`/dev/sda1`) — cold backup only |
| OS | Ubuntu 20.04 (JetPack 5.1.3 — R35 rev 6.4) |
| Network | Gigabit Ethernet + Tailscale (100.100.137.9) |

### 2.1 eMMC Space Budget (Actual)

```
Allocated use               Approx size     Actual (2026-04-19)
────────────────────────────────────────────────────────────────
Ubuntu 20.04 + JetPack      ~12 GB
CUDA / cuDNN / TensorRT     ~4  GB
Node.js (via nvm v24.15.0)  ~200 MB
Ollama binary               ~50 MB
OpenClaw app                ~100 MB         (Phase 3 — ยังไม่ install)
Telegram Bot app            ~50 MB          (Phase 5 — ยังไม่ install)
Nginx                       ~5 MB           (Phase 4 — ยังไม่ install)
PostgreSQL binary           ~50 MB          (Phase 2 — ยังไม่ install)
Redis binary                ~5 MB           (Phase 2 — ยังไม่ install)
/opt/pwd-ai configs + code  ~200 MB
/var/log (with rotation)    ~500 MB
USED (measured)             —               15 GB
FREE (measured)             —               12 GB ✅ safe
────────────────────────────────────────────────────────────────
```

> ❗ **Never store Ollama models on eMMC.** One model = 3–10 GB. เก็บบน MicroSD เท่านั้น

---

## 3. System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                      JETSON AGX XAVIER                           │
│                                                                  │
│  eMMC (OS + binaries + app code)                                 │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │              NATIVE SERVICES via systemd                   │  │
│  │                                                            │  │
│  │  ┌────────────┐   ┌─────────────────────────────────────┐  │  │
│  │  │   Ollama   │◄──│  OpenClaw  (Node.js via nvm)        │  │  │
│  │  │  (native)  │   │  :18789 loopback                    │  │  │
│  │  │  :11434    │   │  ~/.openclaw/openclaw.json          │  │  │
│  │  │            │   │  • API key routing (ollama/cloud)   │  │  │
│  │  │ CUDA/Volta │   │  • Telegram channel (native poll)  │  │  │
│  │  │ GPU infer  │   │  • Skills: gsc-seo, odoo-seo       │  │  │
│  │  └────────────┘   │  • Tailscale serve (HTTPS out)     │  │  │
│  │         ▲         └──────────────┬──────────────────────┘  │  │
│  │  ┌──────┴──────┐  ┌──────────────▼──┐  ┌────────────────┐  │  │
│  │  │ PostgreSQL  │  │    Redis         │  │  Nginx :80/443 │  │  │
│  │  │   :5432     │  │    :6379         │  │  → :18789      │  │  │
│  │  │ 127.0.0.1   │  │  127.0.0.1       │  │  LAN access    │  │  │
│  │  └──────┬──────┘  └──────┬──────────┘  └────────────────┘  │  │
│  │         │                │             ┌────────────────┐   │  │
│  │         │                │             │  Tailscale     │   │  │
│  │         │                │             │  daemon        │   │  │
│  └─────────┼────────────────┼─────────────┴────────────────┘   │  │
│            │                │                                    │  │
│  MicroSD /mnt/pwd-data      │                                    │  │
│  ┌─────────▼────────────────▼─────────────────────────────────┐ │  │
│  │  ollama/models/   postgres/12/main/   redis/   backups/    │ │  │
│  └────────────────────────────────────────────────────────────┘ │  │
└──────────────────────────────────────────────────────────────────┘
          │ LAN (192.168.x.x)              │ Tailscale (100.x.x.x)
          ▼                                ▼
  ┌──────────────┐                ┌─────────────────┐
  │ Office       │                │ Remote / Mobile │
  │ PC, Laptop,  │                │ Don's phone     │
  │ Raspberry Pi │                │ Field devices   │
  └──────────────┘                └─────────────────┘
          │
          ▼ via Telegram (any location, any network)
  ┌──────────────┐
  │ Telegram App │
  └──────────────┘
```

---

## 4. Service Stack — Native systemd Units

```
Unit name                  Runtime           Port        Binds to
────────────────────────────────────────────────────────────────────────
ollama.service             /usr/local/bin    11434       127.0.0.1
openclaw.service           node.js (nvm)     18789       127.0.0.1  ← loopback
nginx.service              system nginx      80, 443     0.0.0.0
postgresql.service         system postgres   5432        127.0.0.1
redis-server.service       system redis      6379        127.0.0.1
tailscaled.service         system tailscale  (managed)   all interfaces
```

**Notes:**
- OpenClaw handles Telegram natively via `channels.telegram` config — no separate bot service needed
- OpenClaw config: `~/.openclaw/openclaw.json` (JSON5, hot-reload for channels/agents)
- OpenClaw Tailscale serve: `https://ubuntu.tailce8ebd.ts.net` (configured via `openclaw onboard`)
- All AI-related ports are bound to `127.0.0.1` only. Only Nginx (80/443) is reachable from LAN

---

## 5. Network Topology

### 5.1 LAN (Office Network)
```
Office device  ──HTTP──►  Nginx :80/:443  ──proxy──►  OpenClaw :3000  ──►  Ollama :11434
                                                    ──►  PostgreSQL :5432
                                                    ──►  Redis :6379
```

### 5.2 Tailscale (Remote / VPN)
```
Tailscale IP:     100.x.x.x
MagicDNS:         jetson-pwd.tail-xxxx.ts.net
Entry point:      Nginx (same as LAN, reachable via Tailscale IP)
ACL:              PWD team Tailscale accounts only
```

### 5.3 Telegram (via OpenClaw native channel)
```
Direction:        Outbound only (long polling — no open inbound port required)
Auth:             allowFrom: [user_id, ...] in openclaw.json > channels.telegram
Path:             Telegram API ◄──poll── OpenClaw :18789 ──► Ollama :11434
Config:           ~/.openclaw/openclaw.json  (channels.telegram section)
No separate bot:  pwd-bot.service not needed — OpenClaw handles Telegram natively
```

---

## 6. USB Drive — Storage Architecture

### 6.1 Mount Configuration

```
Device:       /dev/mmcblk1p1
UUID:         (get after reformat — run: sudo blkid /dev/mmcblk1p1)
Mount point:  /mnt/pwd-data          ← ไม่เปลี่ยน
Filesystem:   ext4                   ← reformat จาก exFAT
Label:        pwd-data-sd
Options:      defaults,nofail,x-systemd.automount
```

> ⚠️ **MicroSD มาพร้อม exFAT — ต้อง reformat เป็น ext4 ก่อนใช้**  
> exFAT ไม่รองรับ Linux file permissions → `chown postgres:postgres` จะ fail  
> → PostgreSQL, Redis, Ollama จะ start ไม่ได้ถ้าใช้ exFAT

**USB Drive (cold backup):**
```
Device:       /dev/sda1
UUID:         9ca0a315-98e9-4164-8858-1972488c659c
Status:       ไม่ mount อัตโนมัติ — เก็บไว้เป็น emergency backup
```

### 6.2 USB Directory Layout
```
/mnt/pwd-data/
├── ollama/
│   └── models/              ← All Ollama model weights (~16 GB for 3 models)
├── postgres/
│   └── 14/
│       └── main/            ← PostgreSQL PGDATA (~1–2 GB)
├── redis/
│   └── dump.rdb             ← Redis persistence snapshot
└── backups/
    ├── postgres/             ← Daily pg_dump .sql.gz
    └── configs/             ← Weekly tar.gz of /opt/pwd-ai + /etc configs
```

### 6.3 MicroSD Space Budget (59.5 GB)

```
Use                          Size        Status
────────────────────────────────────────────────────────────
gemma4:latest                9.6 GB      🟢 migrated จาก USB
qwen3.5:latest               6.6 GB      🟢 migrated (ยัง OOM — พิจารณาลบ)
qwen3.5:4b                   3.4 GB      🟢 migrated — ใช้งาน default
llama3.2:3b                  ~2 GB       🟡 pull ได้หลัง migrate
PostgreSQL data              ~2 GB       🟡 Phase 2
Redis dump                   ~0.1 GB     🟡 Phase 2
Backups (rolling 4wk)        ~4 GB       🟡 Phase 6
Buffer / future models       ~31 GB      ✅ พื้นที่เหลือพอ
────────────────────────────────────────────────────────────
TOTAL used (after migrate)   ~28 GB
FREE                         ~31 GB      ✅
```

### 6.4 Ollama USB Env Override
```ini
# /etc/systemd/system/ollama.service.d/override.conf
[Service]
Environment="OLLAMA_MODELS=/mnt/pwd-data/ollama/models"
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_NUM_PARALLEL=1"
```

### 6.5 PostgreSQL USB Data Directory
```bash
# /etc/postgresql/14/main/postgresql.conf
data_directory = '/mnt/pwd-data/postgres/14/main'
```

### 6.6 Redis USB Persistence
```bash
# /etc/redis/redis.conf
dir /mnt/pwd-data/redis
dbfilename dump.rdb
save 900 1
save 300 10
```

---

## 7. Model Strategy

| Model | USB Size | Status | Use Case | Notes |
|-------|----------|--------|----------|-------|
| `qwen3.5:4b` | 3.4 GB | 🟢 OK | Q&A, SEO, default | ใช้งานได้จริง |
| `gemma4:latest` | 9.6 GB | 🟡 Untested | Article writing? | ยังไม่ได้ทดสอบ inference |
| `qwen3.5:latest` | 6.6 GB | 🔴 OOM | — | Crash ทุกครั้ง (ขนาดใหญ่เกิน?) |
| `llama3.2:3b` | ~2 GB | 🟡 Not pulled | Telegram quick reply | รอ USB space |
| `nomic-embed-text` | ~0.5 GB | 🟡 Not pulled | RAG (future) | รอ USB space |

> **Note:** qwen3.5:latest (6.6 GB) crash ด้วย "model runner has unexpectedly stopped"  
> สาเหตุที่เป็นไปได้: fragmentation ของ unified memory หรือ model load ข้ามขนาด  
> แนะนำลบออกเพื่อเพิ่ม USB space และทดสอบ gemma4:latest แทน

---

## 8. Security Architecture

```
Layer              Control
───────────────────────────────────────────────────────────
UFW Firewall       deny all inbound except 22, 80, 443, Tailscale port
Nginx              SSL, rate limiting, only forwards to localhost:3000
OpenClaw           API key auth per user, configurable rate limits
Telegram Bot       Hardcoded user_id whitelist, no shell access
Ollama             127.0.0.1 binding — not reachable from LAN directly
PostgreSQL         127.0.0.1 + Unix socket only — no remote access
Redis              127.0.0.1 + requirepass enabled
Tailscale          ACL restricts to PWD team accounts only
```

---

## 9. systemd Boot Order & Dependencies

```
Boot sequence (systemd dependency chain):

  network-online.target
        │
        ▼
  tailscaled.service
        │
        ▼
  mnt-pwd\x2ddata.mount        ← automount MicroSD
        │
  ┌─────┴──────────────┐────────────┐
  ▼                    ▼            ▼
postgresql.service   redis-server   ollama.service
        │                    │            │
        └──────────┬──────────┘            │
                   ▼                       │
           openclaw.service ◄──────────────┘
           (user systemd unit — ~/.config/systemd/user/)
           (Telegram polling runs inside OpenClaw — no pwd-bot.service)
                   │
                   ▼
             nginx.service
             (reverse proxy 80 → 127.0.0.1:18789)
```

**Removed:** `pwd-bot.service` — Telegram is handled natively by OpenClaw's `channels.telegram`

All services have `Restart=always` and `RestartSec=5`.

---

## 10. Resilience — USB-specific Risks

| Scenario | Impact | Mitigation |
|----------|--------|------------|
| MicroSD ถอดออกขณะ run | Services crash | `nofail` boot, `ConditionPathIsMountPoint` in units |
| MicroSD ไม่มีตอน boot | Services fail gracefully, OS boots | `nofail` in fstab |
| MicroSD เสีย | Data loss | Weekly pg_dump backup + USB drive เป็น cold backup |
| MicroSD filesystem corruption | Data loss | Weekly config backup, USB cold backup |
| eMMC fills up | OS crash/hang | Log rotation, never store models on eMMC |
| Ollama OOM | Crash + systemd restart | ใช้ qwen3.5:4b เป็น default, หลีกเลี่ยง qwen3.5:latest |
| MicroSD ช้า | Model loading ช้า | MicroSD UHS-I ~60-90 MB/s ยอมรับได้สำหรับ inference |

---

## 11. Full Directory Map

```
eMMC:
~/.openclaw/                ← OpenClaw runtime (nvm global install)
├── openclaw.json           ← Main config (JSON5, hot-reload)
├── workspace/              ← Agent memory, sessions
└── (file-based state — does NOT use PostgreSQL or Redis)

/opt/pwd-ai/
├── scripts/
│   ├── backup.sh           ← cron daily backup        (Phase 6)
│   └── health-check.sh     ← cron 5-min check → Telegram alert  (Phase 6)
└── docs/
    ├── ARCHITECTURE.md     (this file)
    ├── IMPLEMENTATION_PLAN.md
    ├── AGENTS.md
    ├── SOUL.md
    ├── CONTEXT.md
    └── GUARDRAILS.md

MicroSD Card:
/mnt/pwd-data/
├── ollama/models/
├── postgres/12/main/       ← PostgreSQL 12 (not 14)
├── redis/dump.rdb
└── backups/
    ├── postgres/YYYY-MM-DD.sql.gz
    └── configs/YYYY-MM-DD.tar.gz
```

> **Note:** OpenClaw uses its own file-based state in `~/.openclaw/`. The PostgreSQL DB (`openclaw` db, user `openclaw`) and Redis are available for future custom services but OpenClaw itself does not require them.

---

*ARCHITECTURE.md v2.2.0 — Native Install, No Docker, MicroSD Storage, OpenClaw v2026.4.15*
*PWD Vision Works · สันป่าตอง เชียงใหม่*
