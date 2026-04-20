# OpenClaw PWD Vision Works — Master Configuration Plan
## AI-Powered SEO & Content Automation on Jetson AGX Xavier

**Version:** 1.0.0  
**Date:** 2026-04-20  
**Owner:** PWD Vision Works (San Pa Tong, Chiang Mai)  
**Hardware:** NVIDIA Jetson AGX Xavier · Models: llama3.2:3b, qwen3.5:4b  
**Document:** `/opt/pwd-ai/docs/MASTER_PLAN.md`

---

## 🗺️ ภาพรวมสถาปัตยกรรม (Architecture Overview)

```
OpenClaw (Jetson AGX Xavier)
│
├── AGENTS
│   ├── seo-auditor        ← ตรวจสอบ SEO ทุกหน้าเว็บ + ส่งรายงาน Telegram
│   ├── content-writer     ← เขียนเนื้อหาสินค้า (รูปแบบ Odoo ERP)
│   ├── blog-writer        ← เขียนบทความ Blog สำหรับ BS4U-TECH / pwdvisionworks
│   └── sync-verifier      ← ตรวจสอบ D1 Cloudflare ↔ Odoo product sync
│
├── SKILLS
│   ├── gsc-seo            ← Google Search Console API integration
│   ├── odoo-api           ← Odoo JSON-RPC product read/write
│   ├── cloudflare-d1      ← Cloudflare D1 query via Workers API
│   └── telegram-report    ← Telegram message formatting + send
│
├── CRON JOBS
│   ├── daily-seo-report   ← 07:00 ทุกวัน → GSC fetch → report → Telegram
│   ├── weekly-content     ← จันทร์ 09:00 → สร้างเนื้อหาสินค้า batch
│   └── sync-check         ← 06:00 ทุกวัน → D1 ↔ Odoo diff check
│
└── TEMPLATES
    ├── seo-landing.prompt    ← Landing page SEO improvement
    ├── seo-blog.prompt       ← Blog post SEO optimization
    ├── seo-shop.prompt       ← Product page SEO
    ├── product-content.prompt← สร้างเนื้อหาสินค้าเต็มรูปแบบ
    └── blog-content.prompt   ← เขียน blog article ใหม่
```

---

## 📋 Deployment Phases

| Phase | งาน | ไฟล์ที่เกี่ยวข้อง | Priority |
|-------|-----|-----------------|----------|
| 1 | ตั้งค่า Identity + Soul + Agents | IDENTITY.md, SOUL.md, AGENTS.md | ⭐⭐⭐ |
| 2 | ตั้งค่า CONTEXT + GUARDRAILS | CONTEXT.md, GUARDRAILS.md | ⭐⭐⭐ |
| 3 | ติดตั้ง Cron + Daily SEO Report | scripts/daily-seo-cron.sh | ⭐⭐⭐ |
| 4 | SEO Templates (Landing/Blog/Shop) | templates/seo-*.prompt | ⭐⭐ |
| 5 | Product Content Template | templates/product-content.prompt | ⭐⭐ |
| 6 | Blog Writer Agent | agents/blog-writer config | ⭐⭐ |
| 7 | Sync Verifier Agent | agents/sync-verifier config | ⭐ |

---

## 📁 Directory Structure (Jetson)

```
/opt/pwd-ai/
├── docs/
│   ├── MASTER_PLAN.md        (this file)
│   ├── ARCHITECTURE.md       (v2.2.0 — existing)
│   ├── AGENTS.md             ← agent definitions
│   ├── SOUL.md               ← personality + values
│   ├── IDENTITY.md           ← brand identity config
│   ├── CONTEXT.md            ← shared knowledge base
│   └── GUARDRAILS.md        ← safety + accuracy rules
│
├── templates/
│   ├── seo-landing.prompt
│   ├── seo-blog.prompt
│   ├── seo-shop.prompt
│   ├── product-content.prompt
│   └── blog-content.prompt
│
└── scripts/
    ├── daily-seo-cron.sh     ← cron: GSC fetch + report
    ├── sync-check-cron.sh    ← cron: D1 ↔ Odoo verify
    ├── backup.sh             ← (existing)
    └── health-check.sh       ← (existing)

~/.openclaw/
└── openclaw.json             ← main OpenClaw config (JSON5)
```
