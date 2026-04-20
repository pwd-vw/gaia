# GAIA — Global AI Agent Architecture

**สถาปัตยกรรมเอเจนต์ปัญญาประดิษฐ์ระดับโลก** สำหรับ BS4U-TECH Ecosystem

![GAIA Logo](https://via.placeholder.com/800x200/0A2540/00FFAA?text=GAIA+-+Global+AI+Agent+Architecture)  
*(แนะนำ: เปลี่ยนเป็น logo จริงเมื่อมี)*

## 📖 ภาพรวมโครงการ (Overview)

**GAIA** เป็นระบบ **Multi-Agent AI** ที่รันแบบ local บนฮาร์ดแวร์ Edge (NVIDIA Jetson AGX Xavier) โดยใช้ Ollama เป็นหลัก ระบบถูกออกแบบมาเพื่อรองรับงานด้าน SEO, Content Creation, และ Data Synchronization ภายใน ecosystem ของ BS4U-TECH และ pwdvisionworks

GAIA ประกอบด้วยเอเจนต์อัจฉริยะหลายตัวที่ทำงานร่วมกันแบบอัตโนมัติผ่าน Cron jobs และ on-demand

### ✨ คุณสมบัติหลัก (Key Features)

- **SEO Daily Auditor** — ตรวจสอบ SEO ทุกหน้าเว็บด้วย Google Search Console + ส่งรายงานผ่าน Telegram
- **Product Content Writer** — สร้างเนื้อหาสินค้าในรูปแบบ Odoo ERP พร้อม SEO-friendly
- **Blog Article Writer** — เขียนบทความ Blog แบบ Markdown คุณภาพสูง
- **D1 ↔ Odoo Sync Verifier** — ตรวจสอบความแตกต่างระหว่าง Cloudflare D1 และ Odoo แล้วแจ้งเตือน
- รองรับ **Multilingual** (ไทย + อังกฤษ) ด้วยโมเดลที่ optimize สำหรับ Jetson
- ทำงานแบบ **Local-first** และ **Privacy-focused** (ไม่มีข้อมูลออกนอกเครื่อง)
- ใช้ Cron jobs สำหรับการทำงานอัตโนมัติทุกวัน

## 🗺️ สถาปัตยกรรมโดยรวม (Architecture)
OpenClaw (Jetson AGX Xavier 32GB)
│
├── AGENTS
│   ├── seo-auditor
│   ├── content-writer
│   ├── blog-writer
│   └── sync-verifier
│
├── SKILLS
│   ├── gsc-seo (Google Search Console)
│   ├── odoo-api
│   ├── cloudflare-d1
│   └── telegram-report
│
├── CRON JOBS
│   ├── daily-seo-report (07:00)
│   ├── sync-check (06:00)
│   └── weekly-content
│
└── TEMPLATES (Prompt Engineering)

## 🛠️ เทคโนโลยีที่ใช้ (Tech Stack)

- **Hardware**: NVIDIA Jetson AGX Xavier (32GB eMMC + 64GB MicroSD)
- **LLM Runtime**: Ollama (แนะนำ `qwen3:8b` หรือ `qwen3.5:8b` เป็นหลัก)
- **โมเดลหลัก**: Qwen3 / Qwen3.5 8B (Q5_K_M), Llama 3.2 3B (สำหรับงานเบา)
- **Integrations**:
  - Google Search Console API
  - Odoo JSON-RPC
  - Cloudflare D1 (via Workers API)
  - Telegram Bot API
- **ภาษา**: Python (หลัก), Bash (สำหรับ cron)

## 🚀 การติดตั้งและเริ่มใช้งาน (Quick Start)

### Prerequisites
- Jetson AGX Xavier ที่ติดตั้ง JetPack (แนะนำ 5.x หรือ 6.x)
- Ollama ติดตั้งแล้ว (ดูคู่มือ Jetson AI Lab)
- Python 3.10+
- Git

### ขั้นตอนการติดตั้ง

```bash
# 1. Clone repository
git clone https://github.com/yourusername/gaia.git
cd gaia

# 2. ติดตั้ง dependencies
pip install -r requirements.txt

# 3. Pull โมเดลหลักจาก Ollama
ollama pull qwen3:8b
ollama pull llama3.2:3b

# 4. ตั้งค่า Environment Variables
cp .env.example .env
# แก้ไข .env ด้วย API keys (Telegram, Odoo, GSC, Cloudflare)

### การรันเอเจนต์
```Bash
# รันเอเจนต์ด้วยคำสั่ง
python -m agents.seo_auditor

# หรือใช้ cron (ดูโฟลเดอร์ cron/)
```

📁 โครงสร้างโฟลเดอร์ (Project Structure)
textgaia/
├── agents/                 # โค้ดแต่ละเอเจนต์
├── skills/                 # ทักษะและ integration ต่าง ๆ
├── templates/              # Prompt templates
├── cron/                   # สคริปต์ Cron jobs
├── config/
├── logs/
├── .env.example
├── requirements.txt
└── README.md

📅 Cron Jobs ที่ตั้งไว้

06:00 — Sync Verifier (D1 ↔ Odoo)
07:00 — Daily SEO Report → Telegram
จันทร์ 09:00 — Weekly Content Generation

🧩 การพัฒนาและ Contribution
เรายินดีรับ Pull Request!
กรุณาอ่าน CONTRIBUTING.md (ถ้ามี) และ AGENTS.md สำหรับแนวทางการเขียนโค้ดให้ AI Coding Agents เข้าใจง่าย
📄 License
MIT License © 2026 BS4U-TECH

Made with ❤️ on Jetson AGX Xavier
GAIA — Global AI Agent Architecture
Subdomain: gaia.bs4u-tech.com

