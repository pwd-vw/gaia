# CONTEXT.md — Shared Knowledge Base
**Path:** `/opt/pwd-ai/docs/CONTEXT.md`

---

## 1. Business Context

PWD Vision Works จำหน่ายอุปกรณ์อิเล็กทรอนิกส์ Edge AI, SBC, MCU และ IoT  
เป้าหมายหลัก: สร้าง Organic Traffic และ Conversion ผ่าน SEO + Content Marketing

**Revenue channels ที่ต้องสนับสนุน:**
- pwdvisionworks.com (Odoo E-Commerce) — primary sales
- bs4u-tech.com — AdSense + traffic → funnel to pwdvisionworks.com
- LINE OA @104emsoo — ปิดการขายผ่านแชท

---

## 2. SEO Priority Pages

### pwdvisionworks.com
```
Priority 1 (Highest Traffic Potential):
  /shop/*                  ← product pages — ทุกหน้าต้องมี structured data
  /                        ← homepage — hero + value proposition
  /blog/*                  ← articles — long-tail keywords

Priority 2:
  /about                   ← brand trust
  /slide/*                 ← e-learning / tutorials

Priority 3:
  /contactus
  /return-policy
  /privacy-policy
```

### bs4u-tech.com
```
Priority 1:
  /                        ← homepage — tech hub positioning
  /tutorial/*              ← tutorial articles
  /review/*                ← product reviews

Primary content focus:
  - Raspberry Pi tutorials (ภาษาไทย)
  - ESP32 / Arduino projects
  - Edge AI implementation guides
  - Computer Vision with Python/OpenCV
```

---

## 3. Target Keywords Master List

### Cluster 1: SBC / Raspberry Pi
```
Primary:    raspberry pi 5 ราคา, raspberry pi 5 ซื้อที่ไหน
Secondary:  raspberry pi 5 ไทย, pi 5 thailand, บอร์ดสมองกล ราคาถูก
Long-tail:  raspberry pi 5 setup ภาษาไทย, วิธีติดตั้ง raspberry pi 5
```

### Cluster 2: Edge AI
```
Primary:    edge ai thailand, edge ai box ราคา
Secondary:  computer vision board ไทย, ai accelerator hailo
Long-tail:  ระบบ ai ไม่ต้องใช้อินเทอร์เน็ต, offline ai ราคา
```

### Cluster 3: LPR / Solutions
```
Primary:    lpr system thailand, ระบบอ่านป้ายทะเบียน
Secondary:  license plate recognition ราคา, ai ตรวจป้ายทะเบียน
Long-tail:  ระบบ lpr สำหรับหมู่บ้าน, ระบบจอดรถอัจฉริยะ
```

### Cluster 4: ESP32 / IoT
```
Primary:    esp32 ราคา ไทย, iot starter kit
Secondary:  keyestudio esp32 mini, บอร์ด esp32 สำหรับมือใหม่
Long-tail:  esp32 เชื่อมต่อ wifi ทำยังไง, สอน esp32 ภาษาไทย
```

### Cluster 5: Storage
```
Primary:    nvme ssd ราคา, ssd สำหรับ raspberry pi
Secondary:  dahua c900 ราคา, lexar nm620 review
Long-tail:  nvme สำหรับ pi 5 ตัวไหนดี
```

---

## 4. Product Catalog Reference (Active SKUs)

```
# SBC - Single Board Computers
SBC-RPI-RPI5-2G      Raspberry Pi 5 / 2GB
SBC-RPI-RPI5-4G      Raspberry Pi 5 / 4GB  
SBC-RPI-RPI5-8G      Raspberry Pi 5 / 8GB
SBC-RDX-DRAQ6A       Radxa Dragon Q6A

# MCU - Microcontrollers (Keyestudio Batch 1)
MCU-ESP-KS-5019      KS5019 Mini ESP32 ← anchor/highest freq product
# [ดู Master Catalog สำหรับ KS SKU ครบถ้วน]

# Storage
STRG-NVMe-DH-C900-256G  Dahua C900 256GB
STRG-NVMe-DH-C900-512G  Dahua C900 512GB  
STRG-NVMe-LX-NM620-512G Lexar NM620 512GB
```

---

## 5. Competitor Awareness

```
# ห้ามพูดถึงชื่อคู่แข่งในเนื้อหา
# ให้เปรียบเทียบ features ไม่ใช่แบรนด์

แนวทาง:
- "ดีกว่าโซลูชัน Cloud-based ที่ต้องจ่ายค่า API รายเดือน"
- "ไม่ต้องพึ่ง Internet — ทำงานได้ทุกที่แม้ไม่มีสัญญาณ"
- "ราคาถูกกว่าการจ้าง developer ทำระบบเอง"
```

---

## 6. Internal Links Strategy

```
ทุก blog post หรือ product page ต้อง:

1. Link ไปที่ related product ใน /shop/*
2. Link ไปที่ related blog/tutorial
3. Link ไปที่ /contactus หรือ LINE OA อย่างน้อย 1 ครั้ง

ห้าม external link ไปที่คู่แข่ง
External link ที่ยอมรับได้: GitHub, official documentation, Raspberry Pi Foundation
```

---

## 7. GSC API Configuration

```python
# GSC Query Template
{
  "startDate": "YYYY-MM-DD",     # 7 วันที่แล้ว
  "endDate": "YYYY-MM-DD",       # เมื่อวาน (GSC มี 2-3 วัน delay)
  "dimensions": ["page", "query"],
  "rowLimit": 100,
  "dataState": "final"
}

# Sites to monitor:
SITES = [
    "https://www.pwdvisionworks.com/",
    "https://bs4u-tech.com/"
]

# Metrics to track:
METRICS = ["clicks", "impressions", "ctr", "position"]
```

---

## 8. Odoo Product Fields Mapping

```
Odoo Field           → Content Section
─────────────────────────────────────────────────
name                 → product_name (SEO title)
description_sale     → description_sale (2 lines)
description          → description_short (<150 chars)
description_picking  → internal use
description_website  → website_description (HTML)
website_short_description → description_ecommerce (HTML bullets)
website_slug         → url_slug
categ_id             → odoo_category
```
