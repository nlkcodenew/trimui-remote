#!/bin/sh
# clear-logs.sh: don sach log cua Trimui-Remote.
# Dung: sh clear-logs.sh   (nut A tren UI, hoac chay tay qua SSH)
# - truncate cac log dang duoc tien trinh giu mo (khong xoa han de khong mat fd)
# - xoa han cac file Net-survey-*.log (snapshot chan doan chay bang tay)
case "$0" in */*) cd "$(dirname "$0")" || exit 1;; esac
APP="$(pwd)"
n=0
for f in "$APP/Remote-debug.log" "$APP/Remote-ota.log" \
         "$APP/Remote-launcher.log" "$APP/data/tunnel.log"; do
  if [ -f "$f" ] && : > "$f" 2>/dev/null; then n=$((n + 1)); fi
done
m=0
for f in "$APP"/Net-survey-*.log; do
  [ -f "$f" ] || continue
  if rm -f "$f" 2>/dev/null; then m=$((m + 1)); fi
done
echo "da don $n log + xoa $m file Net-survey"
