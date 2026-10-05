#!/bin/sh
# screen.sh: tat/mo den man hinh kieu Music Player, giu may thuc + WiFi song.
# Khac nut Power (suspend = tat WiFi = dut SSH). Dung khi da B-thoat ve menu
# ma van muon tiet kiem pin nhung giu SSH nen.
#   sh screen.sh off     - luu brightness, dat den ve 0 (man den, SSH song)
#   sh screen.sh on      - khoi phuc brightness da luu
#   sh screen.sh status  - dang tat hay sang
# Co che giong Music-Player/files/musicplayer/display.py:
# ioctl(/dev/disp, 0x102, brightness). Can python3 (firmware stock co san).
case "$0" in */*) cd "$(dirname "$0")" || exit 1;; esac
APP="$(pwd)"
DATA="$APP/data"
REC="$DATA/display-restore.json"
DISP=/dev/disp

need_py() {
  command -v python3 >/dev/null 2>&1 || {
    echo "thieu python3 (firmware can co san tu 1.0.4)" >&2; return 1
  }
  [ -e "$DISP" ] || { echo "khong co $DISP" >&2; return 1; }
}

saved_brightness() {
  for f in /mnt/SDCARD/Saves/trim-ui-brick-pro-system.json \
           /mnt/UDISK/system.json /appconfigs/system.json; do
    [ -f "$f" ] || continue
    v="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); v=d.get("backlight", d.get("brightness", 0)); print(int(v))' "$f" 2>/dev/null)"
    [ -n "$v" ] || continue
    if [ "$v" -ge 1 ] 2>/dev/null && [ "$v" -le 10 ] 2>/dev/null; then
      # stock luu thang 1..10 -> doi sang 1..255 nhu Music Player
      python3 -c "print(round(($v - 1) * 254 / 9 + 1))" 2>/dev/null && return 0
    fi
    if [ "$v" -ge 1 ] 2>/dev/null && [ "$v" -le 255 ] 2>/dev/null; then
      echo "$v" && return 0
    fi
  done
  if [ -f "$REC" ]; then
    python3 -c 'import json,sys; print(int(json.load(open(sys.argv[1]))["brightness"]))' "$REC" 2>/dev/null && return 0
  fi
  echo 128
}

disp_set() {
  python3 - "$DISP" "$1" <<'PYEOF' 2>/dev/null
import fcntl, struct, sys
dev, val = sys.argv[1], int(sys.argv[2])
fd = open(dev, "r+b", buffering=0)
fcntl.ioctl(fd, 0x102, struct.pack("LLLL", 0, val, 0, 0))
fd.close()
PYEOF
}

cmd_off() {
  need_py || return 1
  if [ -f "$REC" ]; then echo "man hinh dang TAT (co $REC)"; return 0; fi
  v="$(saved_brightness)"; [ -n "$v" ] || v=128
  mkdir -p "$DATA" 2>/dev/null
  printf '{"brightness": %d}\n' "$v" > "$REC.tmp" 2>/dev/null && mv "$REC.tmp" "$REC" 2>/dev/null
  if disp_set 0; then
    echo "da TAT den man hinh (brightness cu=$v, SSH van song). Bat lai: sh screen.sh on"
  else
    echo "khong tat duoc den (ioctl that bai)" >&2; return 1
  fi
}

cmd_on() {
  need_py || return 1
  v=""
  [ -f "$REC" ] && v="$(python3 -c 'import json,sys; print(int(json.load(open(sys.argv[1]))["brightness"]))' "$REC" 2>/dev/null)"
  [ -n "$v" ] || v="$(saved_brightness)"
  [ -n "$v" ] || v=128
  if disp_set "$v"; then
    rm -f "$REC" 2>/dev/null
    echo "da SANG man hinh (brightness=$v)"
  else
    echo "khong sang duoc den (ioctl that bai)" >&2; return 1
  fi
}

case "${1:-status}" in
  off) cmd_off;; on) cmd_on;;
  status)
    if [ -f "$REC" ]; then echo "man hinh: TAT (den 0, SSH song)"; else echo "man hinh: SANG"; fi;;
  *) echo "dung: $0 off|on|status" >&2; exit 2;;
esac
