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
METHOD="${1:-}"
METHODS=(default alt alt3 alt6)

log()  { printf '\033[1;34m[discord-dpi]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[discord-dpi]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[discord-dpi]\033[0m %s\n' "$*" >&2; exit 1; }

method_args() {
    case "$1" in
        default) echo "--split 1+s --disorder 3+s --tlsrec 3+s --mod-http hcsmix,dcsmix" ;;
        alt)     echo "--disorder 3+s --tlsrec 3+s" ;;
        alt3)    echo "--disorder 1+s --tlsrec 1+s" ;;
        alt6)    echo "--split 1+s --tlsrec 1+s" ;;
        *)       return 1 ;;
    esac
}

if [[ -n "$METHOD" ]]; then
    method_args "$METHOD" >/dev/null || die "Bilinmeyen yöntem: $METHOD (default | alt | alt3 | alt6)"
    METHODS=("$METHOD")
fi

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
if ! make -C "$WORK/byedpi" -j"$(sysctl -n hw.ncpu)" >"$WORK/build.log" 2>&1 \
        || [[ ! -x "$WORK/byedpi/ciadpi" ]]; then
    tail -20 "$WORK/build.log" >&2
    die "Derleme başarısız."
fi

log "Uygulama oluşturuluyor: $APP"
pkill -9 -f "$APP/Contents/Resources/ciadpi" 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$HERE/app/Info.plist" "$APP/Contents/Info.plist"
cp "$HERE/app/launcher.zsh" "$APP/Contents/MacOS/discord-dpi"
cp "$WORK/byedpi/ciadpi" "$APP/Contents/Resources/ciadpi"
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

# ---- DNS kontrolü ------------------------------------------------------------
# ciadpi alan adlarını sistem DNS'iyle çözer. Operatör DNS'i discord.com'u
# sahte bir adrese çözüyorsa hiçbir yöntem işe yaramaz.

active_service() {
    local dev
    dev="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
    networksetup -listallhardwareports 2>/dev/null | awk -v dev="$dev" '
        /^Hardware Port:/ { hp = substr($0, index($0, $3)) }
        /^Device:/        { if ($2 == dev) { print hp; exit } }'
}

first_ip() {
    dscacheutil -q host -a name discord.com 2>/dev/null | awk '/^ip_address:/{print $2; exit}'
}

# Discord, Cloudflare'in 162.159.0.0/16 bloğunda.
dns_ok() { [[ "$(first_ip)" == 162.159.* ]]; }

if dns_ok; then
    log "DNS düzgün: discord.com -> $(first_ip)"
else
    SERVICE="$(active_service)"
    warn "DNS engelli görünüyor: discord.com -> '$(first_ip)' (Discord'un gerçek adresi 162.159.x.x)."
    warn "Şu anki DNS ($SERVICE): $(networksetup -getdnsservers "$SERVICE" 2>/dev/null | tr '\n' ' ')"
    if [[ -n "$SERVICE" && -t 0 ]]; then
        read -r -p "DNS'i Cloudflare (1.1.1.1) yapayım mı? Mac şifren sorulacak. [E/h] " ANSWER
        if [[ ! "$ANSWER" =~ ^[Hh] ]]; then
            sudo networksetup -setdnsservers "$SERVICE" 1.1.1.1 1.0.0.1
            sudo dscacheutil -flushcache
            sudo killall -HUP mDNSResponder 2>/dev/null || true
            sleep 2
            dns_ok && log "DNS düzeltildi: discord.com -> $(first_ip)" \
                   || warn "DNS hâlâ engelli görünüyor: '$(first_ip)'"
        fi
    else
        warn "Düzeltmek için: sudo networksetup -setdnsservers \"$SERVICE\" 1.1.1.1 1.0.0.1"
    fi
fi

# ---- yöntem testi ----------------------------------------------------------

TEST_PORT=1081
CURL_EXIT=0

# Yöntemi geçici bir ciadpi ile dener; discord.com 200 dönerse başarılı.
test_method() {
    local args pid code
    args="$(method_args "$1")"
    # shellcheck disable=SC2086
    "$APP/Contents/Resources/ciadpi" -i http://127.0.0.1 -p $TEST_PORT $args \
        >"$WORK/ciadpi-test.log" 2>&1 &
    pid=$!
    # macOS yeni derlenen programı ilk çalıştırmada tarayabiliyor; açılmasını bekle.
    for _ in {1..100}; do
        nc -z 127.0.0.1 $TEST_PORT 2>/dev/null && break
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
    done
    if ! nc -z 127.0.0.1 $TEST_PORT 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
        warn "ciadpi başlatılamadı: $(tail -3 "$WORK/ciadpi-test.log" | tr '\n' ' ')"
        CURL_EXIT=7
        return 1
    fi
    CURL_EXIT=0
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
        -x http://127.0.0.1:$TEST_PORT https://discord.com/api/v9/gateway)" || CURL_EXIT=$?
    kill -9 "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    [[ "$code" == "200" ]]
}

CHOSEN=""
for m in "${METHODS[@]}"; do
    log "Yöntem deneniyor: $m"
    if test_method "$m"; then
        CHOSEN="$m"
        log "Çalışıyor: $m"
        break
    fi
    warn "$m çalışmadı (curl hata kodu $CURL_EXIT)."
done

if [[ -z "$CHOSEN" ]]; then
    CHOSEN="${METHODS[0]}"
    warn "Hiçbir yöntem discord.com'a ulaşamadı."
    case "$CURL_EXIT" in
        6)      warn "Sebep: alan adı çözülemedi (DNS). DNS'i 1.1.1.1 yapın." ;;
        7)      warn "Sebep: proxy açılmadı ya da bağlantı reddedildi." ;;
        28)     warn "Sebep: zaman aşımı. DNS engeli ya da yavaş bağlantı olabilir; DNS'i 1.1.1.1 yapıp tekrar deneyin." ;;
        35|56)  warn "Sebep: bağlantı operatör tarafından kesiliyor (DPI)." ;;
    esac
    warn "VPN ya da başka bir proxy açıksa kapatıp tekrar deneyin."
fi

method_args "$CHOSEN" > "$APP/Contents/Resources/method.args"

[[ -d /Applications/Discord.app ]] || warn "/Applications/Discord.app bulunamadı, önce Discord'u kurun."
log "Kurulum tamam (yöntem: $CHOSEN). Discord'u artık 'Discord DPI' uygulamasından açın."
