#!/usr/bin/env bash
# Discord DPI kurulumu: byedpi'yi (ciadpi) kaynaktan derler ve
# /Applications/Discord DPI.app uygulamasını oluşturur.
#
# Kullanım:  ./install.sh [yöntem]
# Yöntemler (GoodbyeDPI-Turkey macOS eşlemeleri): default, alt, alt3, alt6

set -euo pipefail

BYEDPI_REPO="https://github.com/hufrea/byedpi.git"
# Test edilen sürüm. Güncellemek için: BYEDPI_REF=main ./install.sh
BYEDPI_REF="${BYEDPI_REF:-988757617951bb7847f245cf0a55dd4b8756c1f9}"

APP="/Applications/Discord DPI.app"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METHOD="${1:-default}"

log() { printf '\033[1;34m[discord-dpi]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[discord-dpi]\033[0m %s\n' "$*" >&2; exit 1; }

case "$METHOD" in
    default) ARGS="--split 1+s --disorder 3+s --tlsrec 3+s --mod-http hcsmix,dcsmix" ;;
    alt)     ARGS="--disorder 3+s --tlsrec 3+s" ;;
    alt3)    ARGS="--disorder 1+s --tlsrec 1+s" ;;
    alt6)    ARGS="--split 1+s --tlsrec 1+s" ;;
    *)       die "Bilinmeyen yöntem: $METHOD (default | alt | alt3 | alt6)" ;;
esac

[[ "$(uname -s)" == "Darwin" ]] || die "Bu betik yalnızca macOS içindir."
if ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install >/dev/null 2>&1 || true
    die "Xcode Command Line Tools gerekli. Açılan pencereden kurup betiği tekrar çalıştırın."
fi
for tool in git make cc; do
    command -v "$tool" >/dev/null 2>&1 || die "'$tool' bulunamadı (xcode-select --install)."
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

log "byedpi indiriliyor ($BYEDPI_REF)"
git clone --quiet "$BYEDPI_REPO" "$WORK/byedpi"
git -C "$WORK/byedpi" -c advice.detachedHead=false checkout --quiet "$BYEDPI_REF"

log "ciadpi derleniyor ($(uname -m))"
make -C "$WORK/byedpi" -j"$(sysctl -n hw.ncpu)" >/dev/null
[[ -x "$WORK/byedpi/ciadpi" ]] || die "Derleme başarısız."

log "Uygulama oluşturuluyor: $APP"
pkill -9 -f "$APP/Contents/Resources/ciadpi" 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$HERE/app/Info.plist" "$APP/Contents/Info.plist"
cp "$HERE/app/launcher.zsh" "$APP/Contents/MacOS/discord-dpi"
cp "$WORK/byedpi/ciadpi" "$APP/Contents/Resources/ciadpi"
printf '%s\n' "$ARGS" > "$APP/Contents/Resources/method.args"
chmod +x "$APP/Contents/MacOS/discord-dpi" "$APP/Contents/Resources/ciadpi"

# Simge olarak kurulu Discord'un simgesini kullan.
DISCORD_ICON="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIconFile' \
    /Applications/Discord.app/Contents/Info.plist 2>/dev/null || true)"
if [[ -n "$DISCORD_ICON" ]]; then
    [[ "$DISCORD_ICON" == *.icns ]] || DISCORD_ICON="$DISCORD_ICON.icns"
    cp "/Applications/Discord.app/Contents/Resources/$DISCORD_ICON" \
        "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null || true
fi

# Apple Silicon'da kopyalanan ikilinin "linker-signed" imzası geçersiz sayılıp
# süreç öldürülebiliyor; ad-hoc imza ile yeniden imzala.
codesign --force --sign - "$APP/Contents/Resources/ciadpi" >/dev/null 2>&1
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

log "Proxy test ediliyor..."
"$APP/Contents/Resources/ciadpi" -i 127.0.0.1 -p 1081 $ARGS >/dev/null 2>&1 &
TEST_PID=$!
sleep 1
CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 \
    --socks5-hostname 127.0.0.1:1081 https://discord.com/api/v9/gateway || true)"
kill -9 "$TEST_PID" 2>/dev/null || true
wait "$TEST_PID" 2>/dev/null || true
if [[ "$CODE" == "200" ]]; then
    log "Test başarılı: discord.com proxy üzerinden erişilebilir."
else
    log "UYARI: Test başarısız (HTTP $CODE). Başka yöntem deneyin: ./install.sh alt3"
fi

[[ -d /Applications/Discord.app ]] || log "UYARI: /Applications/Discord.app bulunamadı, önce Discord'u kurun."
log "Kurulum tamam ($METHOD). Discord'u artık 'Discord DPI' uygulamasından açın."
