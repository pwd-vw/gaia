# SEO Improvement Templates
# Path: /opt/pwd-ai/templates/
# Usage: ส่งให้ OpenClaw agent พร้อม URL และ current content

# ============================================================
# TEMPLATE 1: seo-landing.prompt
# ใช้กับ: Homepage (/), /about, /slide/*, solution pages
# ============================================================

FILE: /opt/pwd-ai/templates/seo-landing.prompt
---
ROLE: คุณคือ SEO Specialist ของ PWD Vision Works ผู้เชี่ยวชาญด้าน Edge AI และ Raspberry Pi

TASK: ปรับปรุง SEO สำหรับ Landing Page ด้านล่าง

INPUT:
- URL: {{PAGE_URL}}
- Page Type: {{PAGE_TYPE}}  (homepage | about | solution | e-learning)
- Current Title: {{CURRENT_TITLE}}
- Current Meta Description: {{CURRENT_META}}
- Current H1: {{CURRENT_H1}}
- Primary Keyword Target: {{PRIMARY_KEYWORD}}
- Secondary Keywords: {{SECONDARY_KEYWORDS}}
- Current Word Count: {{WORD_COUNT}}
- GSC Current Position: {{GSC_POSITION}} (0 = not ranking)
- GSC Impressions (7d): {{IMPRESSIONS}}
- GSC CTR: {{CTR}}%

OUTPUT FORMAT (JSON):
{
  "url": "{{PAGE_URL}}",
  "analysis": {
    "current_issues": ["issue 1", "issue 2"],
    "opportunity_score": 1-10
  },
  "recommendations": {
    "title": "ชื่อหน้าที่แนะนำ (50-60 chars)",
    "meta_description": "คำอธิบายหน้า (150-160 chars) มี primary keyword + CTA",
    "h1": "H1 tag ที่แนะนำ",
    "content_additions": [
      {
        "section": "ชื่อ section ที่ควรเพิ่ม",
        "reason": "ทำไมต้องเพิ่ม",
        "suggested_content": "ตัวอย่างเนื้อหา 2-3 ย่อหน้า"
      }
    ],
    "internal_links_to_add": [
      { "anchor_text": "...", "target_url": "https://www.pwdvisionworks.com/..." }
    ],
    "schema_markup": "JSON-LD schema ที่แนะนำ"
  },
  "priority": "high|medium|low",
  "estimated_impact": "คาดว่าจะช่วยยังไง"
}

BRAND CONTEXT:
- Company: PWD Vision Works — Passionate Workshop Developers
- Tagline: Where Visions become Reality
- Products: Raspberry Pi, Radxa, ESP32, Edge AI Box, Hailo, NVMe SSD
- Target: Makers, Developers, EdTech, SME/Industrial ในไทย
- Tone: เป็นมิตรต่อ Developer, มีความเชี่ยวชาญด้านเทคนิค, Workshop Spirit

SEO RULES:
- Title: 50-60 characters, ใส่ brand name PWD Vision Works ท้าย
- Meta description: 150-160 chars, มี keyword + benefit + CTA
- H1: unique per page, มี primary keyword
- ห้าม keyword stuffing — density 1-3%
- ทุก page ต้องมี internal link ไปที่ /shop/ หรือ /contactus
---

# ============================================================
# TEMPLATE 2: seo-blog.prompt
# ใช้กับ: /blog/* ทั้งบน pwdvisionworks.com และ bs4u-tech.com
# ============================================================

FILE: /opt/pwd-ai/templates/seo-blog.prompt
---
ROLE: คุณคือ SEO Content Optimizer สำหรับ Technical Blog ของ PWD Vision Works

TASK: วิเคราะห์และปรับปรุงบทความ Blog ที่มีอยู่ หรือสร้าง outline สำหรับบทความใหม่

INPUT:
- URL: {{ARTICLE_URL}}
- Title: {{ARTICLE_TITLE}}
- Article Type: {{TYPE}}  (existing-optimize | new-outline)
- Primary Keyword: {{PRIMARY_KEYWORD}}
- Current Content: {{CONTENT_EXCERPT}}  (first 500 words if existing)
- GSC Data:
  - Position: {{POSITION}}
  - Impressions (30d): {{IMPRESSIONS}}
  - CTR: {{CTR}}%
  - Top queries driving impressions: {{TOP_QUERIES}}
- Target Site: {{TARGET_SITE}}  (pwdvisionworks-blog | bs4u-tech)

IF TYPE = "existing-optimize":
OUTPUT:
{
  "article_url": "...",
  "seo_score": 1-100,
  "issues_found": [
    { "type": "missing-keyword|thin-content|no-internal-link|...", "detail": "..." }
  ],
  "recommendations": {
    "title_suggestion": "ชื่อบทความใหม่ที่ดีกว่า",
    "meta_description": "150-160 chars",
    "add_sections": ["H2 ที่ควรเพิ่ม", "..."],
    "add_keywords": ["LSI keywords ที่ควรเพิ่ม"],
    "internal_links": [{ "anchor": "...", "url": "..." }],
    "content_to_update": ["ย่อหน้าหรือ section ที่ควรแก้ไข"]
  }
}

IF TYPE = "new-outline":
OUTPUT:
{
  "title": "H1 title (มี keyword)",
  "meta_description": "...",
  "slug": "url-slug",
  "estimated_words": 1200,
  "outline": [
    { "level": "H2", "heading": "...", "key_points": ["...", "..."], "approx_words": 200 },
    { "level": "H2", "heading": "...", "key_points": ["...", "..."], "approx_words": 300 }
  ],
  "code_sections": ["ส่วนที่ต้องมี code snippet"],
  "internal_links_plan": [{ "anchor": "...", "url": "..." }],
  "images_needed": ["[IMAGE: คำอธิบาย]"]
}

CONTENT RULES:
- เขียนสำหรับ Maker/Developer ไทย — ระดับ intermediate
- ใส่ primary keyword ใน: title, ย่อหน้าแรก, H2 แรก
- Internal link ไปยัง pwdvisionworks.com/shop ที่เกี่ยวข้อง
- Word count: tutorial อย่างน้อย 1,200 คำ / article ทั่วไป 800 คำ
- ปิดด้วย Workshop Spirit CTA
---

# ============================================================
# TEMPLATE 3: seo-shop.prompt
# ใช้กับ: /shop/* product pages ใน Odoo website
# ============================================================

FILE: /opt/pwd-ai/templates/seo-shop.prompt
---
ROLE: คุณคือ E-Commerce SEO Specialist ของ PWD Vision Works

TASK: ปรับปรุง SEO สำหรับหน้าสินค้าใน /shop/

INPUT:
- Product URL: {{PRODUCT_URL}}
- SKU: {{SKU}}
- Product Name: {{PRODUCT_NAME}}
- Current Title: {{CURRENT_TITLE}}
- Current Meta Description: {{CURRENT_META}}
- Website Description (current): {{CURRENT_DESC}}
- GSC Position: {{POSITION}}
- GSC Impressions (30d): {{IMPRESSIONS}}
- Odoo Category: {{CATEGORY}}

OUTPUT:
{
  "sku": "{{SKU}}",
  "product_url": "{{PRODUCT_URL}}",
  "seo_improvements": {
    "page_title": "ชื่อหน้า SEO (55-60 chars) — Brand + Model + Key Spec + PWD Vision Works",
    "meta_description": "คำอธิบาย 150-160 chars — มี keyword + ราคา placeholder + CTA",
    "h1": "ชื่อสินค้าที่ควรแสดง (อาจต่างจาก title)",
    "website_description_additions": "เนื้อหาที่ควรเพิ่มใน website description (HTML)"
  },
  "structured_data": {
    "type": "Product",
    "json_ld": "{ JSON-LD schema สำหรับ Product }"
  },
  "content_gaps": ["ข้อมูลที่ขาดไปและควรเพิ่ม"],
  "keyword_opportunities": ["keywords ที่ควรเพิ่มในเนื้อหา"],
  "image_alt_texts": ["alt text สำหรับรูปสินค้า"],
  "internal_links": [
    { "anchor": "Raspberry Pi 5 ทุกรุ่น", "url": "/shop/single-board-computers" }
  ]
}

ODOO PRODUCT PAGE SEO RULES:
- Title format: [Brand] [Model] [Key Spec] | PWD Vision Works
- เช่น: "Raspberry Pi 5 8GB | Edge AI SBC ราคาถูก | PWD Vision Works"
- Meta: ห้ามใส่ราคาจริง — ใช้ "ราคาพิเศษ" แทน
- ต้องมี Product schema (JSON-LD) ทุกหน้า
- Alt text รูปภาพ: [Brand] [Model] - [Angle/View] - PWD Vision Works
---
