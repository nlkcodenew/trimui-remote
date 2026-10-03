#!/bin/sh
# Trimui-Remote launcher v0.4: chay an, khong man hinh.
# Ly do: muc dich duy nhat la PC remote vao doc log — khong can go gi tren may,
# khong can ban phim ao, khong can doc chu tren man hinh nho.
# Mo app -> bat SSH LAN (+ tunnel Internet ve VPS, port co dinh) -> thoat ngay.
# Dev SSH vao dia chi CO DINH, khong can nhin man hinh may.
case "$0" in */*) cd "$(dirname "$0")" || exit 1;; esac
APP="$(pwd)"
SDCARD_PATH="${SDCARD_PATH:-/mnt/SDCARD}"
export SDCARD_PATH
LOG="$APP/Remote-launcher.log"

# OTA: repo dang PRIVATE nen TAT mac dinh. Bat lai sau khi public: REMOTE_OTA=1.
if [ "$REMOTE_OTA" = "1" ] && [ -x "$APP/ota-update.sh" ]; then
  if command -v timeout >/dev/null 2>&1; then
    timeout 90 sh "$APP/ota-update.sh" --apply >> "$APP/Remote-ota.log" 2>&1 &
  else
    sh "$APP/ota-update.sh" --apply >> "$APP/Remote-ota.log" 2>&1 &
  fi
fi

LAN_OK=0
if sh "$APP/remote.sh" start >> "$LOG" 2>&1; then
  LAN_OK=1
else
  echo "LOI: khong bat duoc SSH LAN, xem $LOG" >> "$LOG" 2>&1
fi

TUN_OK=0
if [ "$REMOTE_NO_TUNNEL" != "1" ]; then
  if sh "$APP/tunnel.sh" start >> "$LOG" 2>&1; then
    TUN_OK=1
  else
    echo "Chua mo duoc tunnel Internet (van SSH LAN duoc)." >> "$LOG" 2>&1
  fi
fi
echo "launch: lan=$LAN_OK tunnel=$TUN_OK" >> "$LOG" 2>&1

# Ghi file trang thai de doc qua the nho khi can debug (khong hien man hinh).
sh "$APP/show-status.sh" --file-only >> "$LOG" 2>&1
exit 0
