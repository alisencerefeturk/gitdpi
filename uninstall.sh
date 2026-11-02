#!/usr/bin/env bash
# /Applications/Discord DPI.app uygulamasını ve çalışan proxy'sini kaldırır.
set -euo pipefail

APP="/Applications/Discord DPI.app"

pkill -f "$APP/Contents/MacOS/discord-dpi" 2>/dev/null || true
pkill -9 -f "$APP/Contents/Resources/ciadpi" 2>/dev/null || true
rm -rf "$APP" "$HOME/Library/Logs/DiscordDPI"
echo "Discord DPI kaldırıldı."
