#!/bin/sh
# screen.sh: tat/mo den man hinh kieu Music Player, giu may thuc + WiFi song.
# Khac nut Power (suspend = tat WiFi = dut SSH). Dung khi da B-thoat ve menu
# ma van muon tiet kiem pin nhung giu SSH nen.
#   sh screen.sh off     - luu brightness, dat den ve 0 (man den, SSH song)
#   sh screen.sh on      - khoi phuc brightness da luu
#   sh screen.sh status  - dang tat hay sang
# Co che giong Music-Player/files/musicplayer/display.py:
# ioctl(/dev/disp, 0x102, brightness) qua bin/dispctl (khong can python3;
# firmware tren may khong co san python3). Fallback python3 neu co.
case "$0" in */*) cd "$(dirname "$0")" || exit 1;; esac
APP="$(pwd)"
DATA="$APP/data"
REC="$DATA/display-restore.json"
DISP=/dev/disp
CTL="$APP/bin/dispctl"

json_int() {
  # $1=file, $2=key. Lay so nguyen dau tien sau "key": (khong can python).
  grep -o "\"$2\"[ ]*:[ ]*[0-9][0-9]*" "$1" 2>/dev/null \
    | grep -o '[0-9][0-9]*$' 2>/dev/null | head -n 1
}

saved_brightness() {
  for f in /mnt/SDCARD/Saves/trim-ui-brick-pro-system.json \
           /mnt/UDISK/system.json /appconfigs/system.json; do
    [ -f "$f" ] || continue
    v="$(json_int "$f" backlight)"
    [ -n "$v" ] || v="$(json_int "$f" brightness)"
    [ -n "$v" ] || continue
    if [ "$v" -ge 1 ] 2>/dev/null && [ "$v" -le 10 ] 2>/dev/null; then
      # stock luu thang 1..10 -> doi sang 1..255 nhu Music Player
      echo $(( (v - 1) * 254 / 9 + 1 )) && return 0
    fi
    if [ "$v" -ge 1 ] 2>/dev/null && [ "$v" -le 255 ] 2>/dev/null; then
      echo "$v" && return 0
    fi
  done
  if [ -f "$REC" ]; then
    v="$(json_int "$REC" brightness)"
    [ -n "$v" ] && { echo "$v"; return 0; }
  fi
  echo 128
}

disp_set() {
  # $1 = 0..255. Uu tien binary rieng (khong can python3).
  if [ -x "$CTL" ] && [ -e "$DISP" ]; then
    "$CTL" "$1" 2>/dev/null && return 0
  fi
  if command -v python3 >/dev/null 2>&1 && [ -e "$DISP" ]; then
    python3 - "$DISP" "$1" <<'PYEOF' 2>/dev/null
import fcntl, struct, sys
dev, val = sys.argv[1], int(sys.argv[2])
fd = open(dev, "r+b", buffering=0)
fcntl.ioctl(fd, 0x102, struct.pack("LLLL", 0, val, 0, 0))
fd.close()
PYEOF
    return $?
  fi
  echo "khong dieu khien duoc den (thieu $CTL, khong co $DISP hoac python3)" >&2
  return 1
}

cmd_off() {
  [ -e "$DISP" ] || { echo "khong co $DISP" >&2; return 1; }
  if [ -f "$REC" ]; then echo "man hinh dang TAT"; return 0; fi
  v="$(saved_brightness)"; [ -n "$v" ] || v=128
  mkdir -p "$DATA" 2>/dev/null
  printf '{"brightness": %d}\n' "$v" > "$REC.tmp" 2>/dev/null && mv "$REC.tmp" "$REC" 2>/dev/null
  if disp_set 0; then
    echo "da TAT den man hinh (brightness cu=$v, SSH van song). Bat lai: sh screen.sh on"
  else
    rm -f "$REC" 2>/dev/null; return 1
  fi
}

cmd_on() {
  [ -e "$DISP" ] || { echo "khong co $DISP" >&2; return 1; }
  v=""
  [ -f "$REC" ] && v="$(json_int "$REC" brightness)"
  [ -n "$v" ] || v="$(saved_brightness)"
  [ -n "$v" ] || v=128
  if disp_set "$v"; then
    rm -f "$REC" 2>/dev/null
    echo "da SANG man hinh (brightness=$v)"
  else
    return 1
  fi
}

case "${1:-status}" in
  off) cmd_off;; on) cmd_on;;
  status)
    if [ -f "$REC" ]; then echo "man hinh: TAT (den 0, SSH song)"; else echo "man hinh: SANG"; fi;;
  *) echo "dung: $0 off|on|status" >&2; exit 2;;
esac
