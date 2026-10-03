#!/bin/sh
# collect-logs.sh: dong goi log de nguoi ho tro ssh vao copy 1 lenh.
# Dung tren may: sh collect-logs.sh  -> ra debug-YYYYMMDD-HHMMSS.tgz
# Dung tu xa:    ssh root@IP -p 2222 "sh /mnt/SDCARD/Apps/TrimuiRemote/collect-logs.sh"
case "$0" in */*) cd "$(dirname "$0")" || exit 1;; esac
APP="$(pwd)"
SDCARD_PATH="${SDCARD_PATH:-/mnt/SDCARD}"
STAMP="$(date +%Y%m%d-%H%M%S 2>/dev/null)"
[ -n "$STAMP" ] || STAMP=unknown-time
OUT="$APP/data/debug-$STAMP.tgz"
mkdir -p "$APP/data" 2>/dev/null
TMP="$(mktemp -d 2>/dev/null || echo /tmp/dbg-$STAMP)"
mkdir -p "$TMP" 2>/dev/null
{
  echo "=== remote status ==="; sh "$APP/remote.sh" status 2>&1
  echo "=== date/uname ==="; date 2>&1; uname -a 2>&1
  echo "=== ip ==="; ip -4 addr show 2>&1 | head -20
  echo "=== mem ==="; grep -e MemTotal -e MemAvailable /proc/meminfo 2>&1
  echo "=== dmesg ==="; dmesg 2>&1 | tail -100
} > "$TMP/status.txt" 2>&1
tar -czf "$OUT" -C "$SDCARD_PATH" Logs 2>/dev/null
tar -tzf "$OUT" >/dev/null 2>&1 || tar -czf "$OUT" -C "$TMP" status.txt 2>/dev/null
if [ -f "$OUT" ]; then
  (cd "$TMP" && tar -rzf "$OUT" status.txt 2>/dev/null) || true
  echo "saved: $OUT"
  ls -l "$OUT"
else
  echo "khong tao duoc $OUT" >&2; exit 1
fi
rm -rf "$TMP" 2>/dev/null
