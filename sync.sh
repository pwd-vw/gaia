#!/bin/bash
# Sync local openclaw files to AGX dev machine
rsync -avz --exclude='__pycache__' --exclude='*.pyc' --exclude='.env' \
  -e "ssh -i $HOME/.ssh/id_ed25519_agx" \
  /Users/sqh/openclaw/ agx@192.168.1.177:~/openclaw/
