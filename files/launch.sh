#!/bin/sh
# Trimui-Remote launcher v0.5.
# Mo app -> OTA nen ban moi (repo da public) -> tu restart chay ban moi ->
# bat SSH LAN + tunnel Internet -> hien man hinh huong dan -> B de thoat
# (dich vu van chay nen).
case "$0" in */*) cd "$(dirname "$0")" || exit 1;; esac
APP="$(pwd)"
SDCARD_PATH="${SDCARD_PATH:-/mnt/SDCARD}"
export SDCARD_PATH
LOG="$APP/Remote-launcher.log"
VER="$(cat "$APP/VERSION" 2>/dev/null | tr -d ' \r\n')"

# 1. OTA chay TRUOC (foreground, toi da 60s). Co ban moi -> restart app 1 lan
# de chay code moi ngay, khong can mo app 2 lan. Tat bang REMOTE_NO_OTA=1.
if [ "$REMOTE_RESTARTED" != "1" ] && [ "$REMOTE_NO_OTA" != "1" ] && [ -x "$APP/ota-update.sh" ]; then
  if command -v timeout >/dev/null 2>&1; then
    timeout 60 sh "$APP/ota-update.sh" --apply >> "$APP/Remote-ota.log" 2>&1
    CODE=$?
  else
    sh "$APP/ota-update.sh" --apply >> "$APP/Remote-ota.log" 2>&1
    CODE=$?
  fi
  # ota-update.sh exit 0 = vua len ban moi.
  if [ "$CODE" = "0" ]; then
    echo "OTA len ban moi, khoi dong lai app..." >> "$LOG" 2>&1
    sh "$APP/remote.sh" stop >> "$LOG" 2>&1
    sh "$APP/tunnel.sh" stop >> "$LOG" 2>&1
    export REMOTE_RESTARTED=1
    exec sh "$APP/launch.sh"
  fi
fi

# 2. SSH LAN (bat buoc).
LAN_OK=0
if sh "$APP/remote.sh" start >> "$LOG" 2>&1; then
  LAN_OK=1
else
  echo "LOI: khong bat duoc SSH LAN, xem $LOG" >> "$LOG" 2>&1
fi

# 3. Tunnel Internet (mac dinh BAT; tat bang REMOTE_NO_TUNNEL=1).
TUN_OK=0
if [ "$REMOTE_NO_TUNNEL" != "1" ]; then
  if sh "$APP/tunnel.sh" start >> "$LOG" 2>&1; then
    TUN_OK=1
  else
    echo "Chua mo duoc tunnel Internet (van SSH LAN duoc)." >> "$LOG" 2>&1
  fi
fi
echo "launch: lan=$LAN_OK tunnel=$TUN_OK ver=$VER" >> "$LOG" 2>&1

# 4. Ghi file trang thai + hien man hinh huong dan chu TO.
sh "$APP/show-status.sh" --file-only >> "$LOG" 2>&1
export LD_LIBRARY_PATH="$APP/libs:/usr/trimui/lib:/usr/lib64:/usr/lib:/lib:$LD_LIBRARY_PATH"
if [ -x "$APP/bin/remote-ui" ]; then
  IP="$(sh "$APP/remote.sh" ip 2>/dev/null)"
  "$APP/bin/remote-ui" "$IP" "$VER" "$APP" 2>> "$LOG"
fi
exit 0
