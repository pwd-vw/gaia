# OpenClaw — SEO + GSC Analysis Project

## Project Goal
Optimize pwdvisionworks.com SEO using Google Search Console data analyzed by local Ollama LLMs running on a Jetson Xavier AGX.

## Dev Machine (AGX)
- **SSH alias**: `ssh agx` (key: `~/.ssh/id_ed25519_agx`)
- **Local IP**: `192.168.1.177` — user: `agx`, password: `admin88366`
- **Tailscale IP**: `100.100.137.9` — alias: `ssh agx-tail`
- **Tailscale domain**: `ubuntu.tailce8ebd.ts.net`
- **sudo password**: `admin88366`

## Remote Workspace: `~/openclaw/`
```
~/openclaw/
├── .env                  # API keys and config
├── venv/                 # Python 3.8 virtualenv
├── gsc/                  # Google Search Console OAuth files
│   ├── gsc-desktop-client.json
│   ├── get_gsc_token.py  # Run once to generate token.json
│   └── token.json        # OAuth refresh token (generate first)
├── seo/
│   └── gsc_analyzer.py   # Main analysis script
├── ollama/               # Ollama-related scripts
├── data/                 # Analysis output files
└── logs/
```

## Ollama Models Available on AGX
- `gemma4:latest` (9.6 GB)
- `qwen3.5:latest` (6.6 GB) — default for SEO analysis
- `qwen3.5:4b` (3.4 GB) — faster/lighter option

Ollama API: `http://localhost:11434` (active as systemd service)

## Site: pwdvisionworks.com (Odoo)
Target pages for SEO: **Home**, **Products**, **Blog**

Fields to update via Odoo API:
- `website_meta_title`
- `website_description`
- `website_meta_keywords`

## Running the Analyzer
```bash
ssh agx
cd ~/openclaw
# First time only:
venv/bin/python gsc/get_gsc_token.py  # saves token.json

# Run analysis:
venv/bin/python seo/gsc_analyzer.py
```

## Syncing Files from Mac → AGX
```bash
cd ~/openclaw && ./sync.sh
```

## Key APIs
- Google Search Console: OAuth2 (Desktop app flow)
- Ollama: REST at `http://localhost:11434`
- Odoo: XML-RPC at `https://pwdvisionworks.odoo.com`
- Telegram Bot: `@pwdcybi_ceo_bot` for notifications
