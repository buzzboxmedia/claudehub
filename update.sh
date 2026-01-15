#!/bin/bash
# ClaudeHub Update Script
# Pulls latest code, builds, and installs

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Pulling latest changes..."
git pull

echo ""
./install.sh
