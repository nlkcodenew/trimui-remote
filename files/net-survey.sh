#!/bin/sh
# net-survey.sh: thu thap mang + SSH de chot phuong an LAN / tu xa.
# Chay trong Trimui Terminal hoac qua adb/shell: sh net-survey.sh
# Ket qua: Net-survey-YYYYMMDD-HHMMSS.log nam canh file nay -> gui cho dev.
case "$0" in */*) cd "$(dirname "$0")" || exit 1;; esac
APP="$(pwd)"
STAMP="$(date +%Y%m%d-%H%M%S 2>/dev/null)"
[ -n "$STAMP" ] || STAMP=unknown-time
OUT="$APP/Net-survey-$STAMP.log"
{
echo "===== trimui-remote net-survey ====="
date 2>&1
uname -a 2>&1
echo "--- model ---"
cat /sys/firmware/devicetree/base/model 2>/dev/null; echo
cat /proc/device-tree/model 2>/dev/null; echo
echo "--- cpu/mem (RAM 1GB?) ---"
grep -e MemTotal /proc/meminfo 2>&1
cat /proc/cpuinfo 2>/dev/null | grep -e "model name" -e Hardware | head -5
echo "--- ssh tools co san ---"
command -v dropbear dropbearkey dbclient sshd ssh scp autossh 2>&1
echo "--- dang chay ---"
ps 2>&1 | grep -i -e dropbear -e sshd -e tailscale | head
echo "--- mang ---"
ip -4 addr show 2>&1 | head -30
echo "--- wifi ---"
iwconfig 2>&1 | head -20
cat /proc/net/wireless 2>&1 | head
echo "--- route/dns ---"
ip route 2>&1 | head
cat /etc/resolv.conf 2>&1 | head
echo "--- ping lan (gateway) ---"
GW="$(ip route 2>/dev/null | awk '/default/ {print $3; exit}')"
echo "gateway=$GW"
[ -n "$GW" ] && ping -c 2 -W 2 "$GW" 2>&1 | tail -5
echo "--- tun (cho tailscale sau nay) ---"
ls -l /dev/net/tun 2>&1
zcat /proc/config.gz 2>/dev/null | grep -i -e CONFIG_TUN -e WIREGUARD | head
echo "--- logs o dau ---"
ls -d /mnt/SDCARD/Logs "$APP/../"* 2>&1 | head
df -h "$APP" 2>&1 | head -5
echo "APP=$APP"
} > "$OUT" 2>&1
echo "saved: $OUT"
