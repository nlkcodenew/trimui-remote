#!/bin/sh
# Trimui-Remote launcher v0.3: NHE + CHAY NEN, co man hinh thong tin.
# Mo app -> bat SSH LAN (+ tunnel Internet) -> hien IP/user/pass -> o lai
# cho den khi ban thoat (B 2 lan). Dich vu chay nen van o lai sau khi thoat.
case "$0" in */*) cd "$(dirname "$0")" || exit 1;; esac
APP="$(pwd)"
SDCARD_PATH="${SDCARD_PATH:-/mnt/SDCARD}"
export SDCARD_PATH
LOG="$APP/Remote-launcher.log"

# OTA: repo dang PRIVATE nen manifest khong tai duoc -> TAT mac dinh.
# Muon bat (sau khi public repo): mo app voi REMOTE_OTA=1.
if [ "$REMOTE_OTA" = "1" ] && [ -x "$APP/ota-update.sh" ]; then
  if command -v timeout >/dev/null 2>&1; then
    timeout 90 sh "$APP/ota-update.sh" --apply >> "$APP/Remote-ota.log" 2>&1 &
  else
    sh "$APP/ota-update.sh" --apply >> "$APP/Remote-ota.log" 2>&1 &
  fi
fi

# 1. SSH LAN (bat buoc).
LAN_OK=0
if sh "$APP/remote.sh" start >> "$LOG" 2>&1; then
  LAN_OK=1
else
  echo "LOI: khong bat duoc SSH LAN, xem $LOG" >> "$LOG" 2>&1
fi

# 2. Tunnel Internet (mac dinh BAT; tat bang REMOTE_NO_TUNNEL=1).
TUN_OK=0
if [ "$REMOTE_NO_TUNNEL" != "1" ]; then
  if sh "$APP/tunnel.sh" start >> "$LOG" 2>&1; then
    TUN_OK=1
  else
    echo "Chua mo duoc tunnel Internet (van SSH LAN duoc)." >> "$LOG" 2>&1
  fi
fi
echo "launch: lan=$LAN_OK tunnel=$TUN_OK" >> "$LOG" 2>&1

# 3. Man hinh thong tin: dung TrimuiTerminal (neu co) de hien.
TERM_BIN=""
for t in "$SDCARD_PATH/Apps/TrimuiTerminal/bin/trimui-terminal" \
         "$SDCARD_PATH/Apps/Trimui-Terminal/bin/trimui-terminal"; do
  if [ -x "$t" ]; then TERM_BIN="$t"; break; fi
done
export LD_LIBRARY_PATH="$APP/libs:/usr/trimui/lib:/usr/lib64:/usr/lib:/lib:$LD_LIBRARY_PATH"
if [ -n "$TERM_BIN" ]; then
  TERMINAL_NO_OTA=1 "$TERM_BIN" -nointro -scale 1 -fontsize 16 \
    -r "sh \"$APP/show-status.sh\"" 2>> "$LOG"
  CODE=$?
else
  # Fallback khong co Terminal: ghi file + thoat (doc tren may tinh).
  sh "$APP/show-status.sh" --file-only >> "$LOG" 2>&1
  echo "Khong thay TrimuiTerminal -> da ghi $APP/STATUS.txt, mo file de xem." >> "$LOG" 2>&1
  CODE=0
fi
exit "$CODE"
