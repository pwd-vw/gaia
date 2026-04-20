# GUARDRAILS.md — AI Safety & Accuracy Rules
**Path:** `/opt/pwd-ai/docs/GUARDRAILS.md`

---

## 🚫 ABSOLUTE PROHIBITIONS (ห้ามเด็ดขาด)

```
❌ ห้ามสร้างหรือประมาณราคาสินค้า — ราคาต้องมาจาก Odoo เท่านั้น
❌ ห้ามเขียนสเปกที่ไม่ได้อยู่ใน Raw Data ที่ได้รับ
❌ ห้าม auto-approve การ sync ข้อมูล ต้องรอ Ken ยืนยันเสมอ
❌ ห้าม log credentials (API keys, passwords) ใน output ใดๆ
❌ ห้ามเขียนเนื้อหาที่ทำให้เข้าใจผิดเกี่ยวกับ shipping time หรือ warranty
❌ ห้ามพูดถึงชื่อคู่แข่งโดยตรงในเนื้อหา public
❌ ห้ามส่ง raw financial data (ต้นทุน, COGS, margin) ผ่าน Telegram
```

---

## ⚠️ CAUTION ZONES (ต้องระวัง)

```
⚠️ ราคา: ถ้าต้องอ้างอิงราคา → ให้บอกว่า "ดูราคาที่ pwdvisionworks.com"
⚠️ สต็อก: ถ้าต้องพูดถึงสต็อก → ใช้ "มีสินค้า" / "สินค้าหมด" จาก Odoo เท่านั้น
⚠️ Shipping: ไม่ระบุเวลาจัดส่ง — ให้ลูกค้าถามผ่าน LINE OA
⚠️ Technical claims: ทุก performance claim ต้องอ้างอิง datasheet หรือ test จริง
⚠️ SEO recommendations: ต้องอิงจาก GSC actual data ไม่ใช่ assumption
```

---

## ✅ APPROVED BEHAVIORS (พฤติกรรมที่ต้องการ)

```
✅ เมื่อไม่แน่ใจ → แจ้ง uncertainty อย่างชัดเจน ไม่ใช่การสมมติ
✅ เมื่อ data ไม่ครบ → ขอข้อมูลเพิ่มเติม ไม่เติมเอง
✅ เมื่อ API fail → log error + notify Ken ทาง Telegram ทันที
✅ เมื่อ content ไม่แน่ใจคุณภาพ → flag สำหรับ human review
✅ รายงาน SEO ต้องระบุว่าข้อมูลมาจาก GSC date range ใด
✅ Product content ต้องระบุว่า raw data มาจากแหล่งใด
```

---

## 📊 Quality Thresholds

### SEO Audit
```
Report ต้องส่งภายใน: 5 นาทีหลัง cron trigger
ถ้าช้ากว่า: บันทึก log และแจ้ง Telegram
Data freshness: ยอมรับ GSC data delay สูงสุด 3 วัน
ถ้า data เก่ากว่า 3 วัน: แจ้งใน report
```

### Product Content
```
Word count website_description: อย่างน้อย 300 คำ
description_short: ไม่เกิน 150 ตัวอักษร (นับ)
Mandatory footer: ต้องมีทุกครั้ง — ถ้าไม่มี = reject
Keyword density: 1-3% ของ word count (ไม่ stuffing)
```

### Sync Verification
```
Tolerance price diff: ±5% (ถ้าเกิน → flag critical)
Tolerance stock diff: 0 units (ต่างกัน 1 ชิ้น = warning)
Max items per report: 50 SKUs ต่อ run
ถ้า issue > 10 items: ส่ง file attachment แทน inline message
```

---

## 🔄 Retry & Fallback Policy

```
Model generation failure:
  → Retry 1 ครั้งด้วย temperature -0.1
  → Retry 2 ครั้งด้วย temperature 0.2 (minimum)
  → ถ้า 3 ครั้งยังไม่ผ่าน → flag for human review

API rate limit:
  → Wait 60 seconds → retry
  → ถ้า 3 ครั้งยังไม่ผ่าน → reschedule +1 ชั่วโมง

Telegram send failure:
  → Retry 3 ครั้ง interval 30 seconds
  → ถ้ายังไม่ได้ → บันทึก report ใน /mnt/pwd-data/reports/ แทน
```

---

## 📝 Logging Standards

```
Log file: /var/log/pwd-ai/openclaw-YYYY-MM-DD.log
Log format: [TIMESTAMP] [AGENT_ID] [LEVEL] [MESSAGE]

LEVELS:
  INFO  = งานปกติ สำเร็จ
  WARN  = งานสำเร็จแต่มีข้อสังเกต
  ERROR = งานล้มเหลว มี fallback
  CRIT  = งานล้มเหลวทั้งหมด ต้องการ human intervention

Log rotation: ทุก 7 วัน เก็บ 30 วัน
Max log size per day: 100 MB
Sensitive data: ห้าม log API keys, passwords, personal data
```
