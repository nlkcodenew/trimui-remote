#!/bin/sh
# Trimui-Remote launcher: NHE + CHAY NEN, cho Brick Pro / Smart Pro S (RAM 1GB).
# Nguyen tac v0.1:
# - Mo app la bat SSH (dropbear) roi THOAT NGAY, dropbear o lai chay nen.
# - Khong giu UI SDL/Python nang: tiet kiem RAM cho game.
# - Muon tat: mo app lan nua (toggle), hoac sh remote.sh stop.
case "$0" in */*) cd "$(dirname "$0")" || exit 1;; esac
APP="$(pwd)"
SDCARD_PATH="${SDCARD_PATH:-/mnt/SDCARD}"
export SDCARD_PATH
LOG="$APP/Remote-launcher.log"

# OTA nen giong Terminal/Xiaozhi: mo app ngay, update tu chay nen, offline bo qua.
if [ -x "$APP/ota-update.sh" ] && [ "$REMOTE_NO_OTA" != "1" ]; then
  if command -v timeout >/dev/null 2>&1; then
    timeout 90 sh "$APP/ota-update.sh" --apply >> "$APP/Remote-ota.log" 2>&1 &
  else
    sh "$APP/ota-update.sh" --apply >> "$APP/Remote-ota.log" 2>&1 &
  fi
fi

# Toggle: dang chay -> tat; chua chay -> bat.
if sh "$APP/remote.sh" status >/dev/null 2>&1; then
  sh "$APP/remote.sh" stop >> "$LOG" 2>&1
  echo "Trimui-Remote: da TAT SSH (dropbear dung)." >> "$LOG" 2>&1
else
  sh "$APP/remote.sh" start >> "$LOG" 2>&1
  echo "Trimui-Remote: da BAT SSH. Xem Remote-ip.txt de lay IP." >> "$LOG" 2>&1
fi
exit 0
