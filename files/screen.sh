#!/bin/sh
# screen.sh: tat/mo den man hinh kieu Music Player, giu may thuc + WiFi song.
# Khac nut Power (suspend = tat WiFi = dut SSH). Dung khi da B-thoat ve menu
# ma van muon tiet kiem pin nhung giu SSH nen.
#   sh screen.sh off     - luu brightness, dat den ve 0 (man den, SSH song)
#   sh screen.sh on      - khoi phuc brightness da luu
#   sh screen.sh status  - dang tat hay sang
# Co che:
#   - Brick Pro: ioctl(/dev/disp, 0x102, brightness) qua bin/dispctl
#     (khong can python3; firmware tren may khong co san python3).
#   - Smart Pro S: khong co /dev/disp -> dung sysfs
#     /sys/class/backlight/backlight0/brightness (ghi truc tiep).
#   - Fallback python3 neu co.
case "$0" in */*) cd "$(dirname "$0")" || exit 1;; esac
APP="$(pwd)"
DATA="$APP/data"
REC="$DATA/display-restore.json"
DISP=/dev/disp
CTL="$APP/bin/dispctl"
# Tim backlight sysfs (Smart Pro S khong co /dev/disp).
BL=""
for d in /sys/class/backlight/*/brightness; do
  [ -w "$d" ] && { BL="$d"; break; }
done

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

cur_brightness() {
  # Do sang hien tai truc tiep tu sysfs (chinh xac nhat khi co).
  if [ -n "$BL" ]; then
    v="$(cat "$BL" 2>/dev/null)"; max="$(cat "${BL%/*}/max_brightness" 2>/dev/null)"
    if [ -n "$v" ] && [ -n "$max" ] && [ "$max" -gt 0 ] 2>/dev/null; then
      if [ "$max" -eq 255 ] 2>/dev/null; then echo "$v"; else echo $(( v * 255 / max )); fi
      return 0
    fi
  fi
  return 1
}

bl_set() {
  # $1 = 0..255. Ghi truc tiep sysfs, scale theo max_brightness.
  [ -n "$BL" ] || return 1
  max="$(cat "${BL%/*}/max_brightness" 2>/dev/null)"; [ -n "$max" ] || max=255
  if [ "$max" -eq 255 ] 2>/dev/null; then v="$1"; else v=$(( $1 * max / 255 )); fi
  echo "$v" > "$BL" 2>/dev/null
}

disp_set() {
  # $1 = 0..255. Thu tu: /dev/disp (Brick Pro) -> sysfs (Smart Pro S) -> python3.
  if [ -x "$CTL" ] && [ -e "$DISP" ]; then
    "$CTL" "$1" 2>/dev/null && return 0
  fi
  if [ -n "$BL" ]; then
    bl_set "$1" && return 0
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
  echo "khong dieu khien duoc den (khong co $DISP, khong co backlight sysfs, thieu python3)" >&2
  return 1
}

has_method() {
  { [ -x "$CTL" ] && [ -e "$DISP" ]; } || [ -n "$BL" ] || { command -v python3 >/dev/null 2>&1 && [ -e "$DISP" ]; }
}

cmd_off() {
  has_method || { echo "khong co cach dieu khien den man hinh" >&2; return 1; }
  if [ -f "$REC" ]; then echo "man hinh dang TAT"; return 0; fi
  v="$(cur_brightness 2>/dev/null)" || v=""
  [ -n "$v" ] || v="$(saved_brightness)"; [ -n "$v" ] || v=128
  mkdir -p "$DATA" 2>/dev/null
  printf '{"brightness": %d}\n' "$v" > "$REC.tmp" 2>/dev/null && mv "$REC.tmp" "$REC" 2>/dev/null
  if disp_set 0; then
    echo "da TAT den man hinh (brightness cu=$v, SSH van song). Bat lai: sh screen.sh on"
  else
    rm -f "$REC" 2>/dev/null; return 1
  fi
}

cmd_on() {
  has_method || { echo "khong co cach dieu khien den man hinh" >&2; return 1; }
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
