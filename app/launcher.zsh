#!/bin/zsh
# Discord DPI.app başlatıcısı.
# GoodbyeDPI-Turkey'nin macOS yöntemini (byedpi / ciadpi, HTTP proxy) 127.0.0.1:1080'de
# başlatır, Discord'u bu proxy ile açar ve Discord kapanınca proxy'yi de kapatır.

res="${0:A:h:h}/Resources"
ciadpi="$res/ciadpi"
args=(${(z)"$(<"$res/method.args")"})
port=1080
proxy_url="http://127.0.0.1:$port"
discord_app=/Applications/Discord.app
discord_bin="$discord_app/Contents/MacOS/Discord"
log="$HOME/Library/Logs/DiscordDPI"
mkdir -p "$log"

alert() {
  /usr/bin/osascript -e "display alert \"Discord DPI\" message \"$1\" as critical" >/dev/null 2>&1
}

discord_pid() {
  /usr/bin/pgrep -f "^$discord_bin( |\$)" 2>/dev/null | head -1
}

launch_discord() {
  # Güncelleyici Chromium'un proxy ayarını değil ortam değişkenlerini kullanıyor.
  /usr/bin/open -a "$discord_app" \
    --env HTTP_PROXY="$proxy_url" --env HTTPS_PROXY="$proxy_url" \
    --env ALL_PROXY="$proxy_url" --env NO_PROXY=localhost,127.0.0.1 \
    --args --proxy-server="$proxy_url" '--proxy-bypass-list=<-loopback>' --disable-quic
}

# Proxy ayarı olmadan açılmış Discord'u kapatıp proxy ile yeniden açar.
relaunch_discord() {
  local pid=$1
  /usr/bin/osascript -e 'quit app "Discord"' >/dev/null 2>&1
  for i in {1..50}; do
    /bin/kill -0 "$pid" 2>/dev/null || break
    /bin/sleep 0.2
  done
  /bin/kill -0 "$pid" 2>/dev/null && /bin/kill -TERM "$pid" 2>/dev/null && /bin/sleep 1
  launch_discord
}

if [[ ! -x $discord_bin ]]; then
  alert "Discord bulunamadı ($discord_app). Önce Discord'u kurun."
  exit 1
fi

# Proxy: zaten çalışan bizim ciadpi'miz varsa onu sahiplen, yoksa başlat.
listener=$(/usr/sbin/lsof -nP -t -iTCP:$port -sTCP:LISTEN 2>/dev/null | head -1)
if [[ -n $listener ]]; then
  if [[ "$(/bin/ps -p $listener -o comm= 2>/dev/null)" != *ciadpi ]]; then
    alert "$port portu başka bir program tarafından kullanılıyor."
    exit 1
  fi
  proxy_pid=$listener
else
  "$ciadpi" -i http://127.0.0.1 -p $port "${args[@]}" >>"$log/ciadpi.log" 2>&1 &
  proxy_pid=$!
  for i in {1..30}; do
    /usr/bin/nc -z 127.0.0.1 $port 2>/dev/null && break
    /bin/sleep 0.1
  done
  if ! /usr/bin/nc -z 127.0.0.1 $port 2>/dev/null; then
    alert "Proxy (ciadpi) başlatılamadı. Ayrıntı: $log/ciadpi.log"
    exit 1
  fi
fi

pid=$(discord_pid)
if [[ -z $pid ]]; then
  launch_discord
elif [[ "$(/bin/ps -p $pid -o command= 2>/dev/null)" != *"--proxy-server=$proxy_url"* ]]; then
  relaunch_discord $pid
else
  /usr/bin/open -a "$discord_app"
fi

# Discord açık kaldıkça bekle; güncelleme sonrası proxy'siz yeniden açılırsa düzelt.
seen=0 missing=0
while /bin/kill -0 $proxy_pid 2>/dev/null; do
  pid=$(discord_pid)
  if [[ -n $pid ]]; then
    seen=1 missing=0
    if [[ "$(/bin/ps -p $pid -o command= 2>/dev/null)" != *"--proxy-server=$proxy_url"* ]]; then
      relaunch_discord $pid
    fi
  else
    (( missing++ ))
    (( seen && missing >= 5 )) && break    # Discord ~10 sn'dir kapalı
    (( !seen && missing >= 60 )) && break  # Discord 2 dk içinde hiç açılmadı
  fi
  /bin/sleep 2
done

/bin/kill -9 $proxy_pid 2>/dev/null
exit 0
