#!/bin/sh
# remote.sh: quan ly dropbear chay nen, sieu nhe cho may 1GB RAM.
# Dung: sh remote.sh start|stop|restart|status|ip
#   start  - sinh host-key lan dau, chay dropbear nen, ghi Remote-ip.txt
#   stop   - tat dropbear cua app (khong dung den SSH cua he thong)
#   status - exit 0 neu dang chay, in PID + port + IP
#   ip     - chi in IP LAN
# Bien moi truong:
#   REMOTE_PORT (mac dinh 2222), REMOTE_PASS_FILE, REMOTE_PUBKEY (authorized_keys)
case "$0" in */*) cd "$(dirname "$0")" || exit 1;; esac
APP="$(pwd)"
DATA="$APP/data"
BIN_DROPBEAR="$APP/bin/dropbear"
SYS_DROPBEAR="$(command -v dropbear 2>/dev/null)"
PORT="${REMOTE_PORT:-2222}"
PIDF="$DATA/dropbear.pid"
KEYF="$DATA/dropbear_host_key"
AUTHKEYS="$DATA/authorized_keys"
IPFILE="$APP/Remote-ip.txt"
LOG="$APP/Remote-debug.log"

mkdir -p "$DATA" 2>/dev/null
pick_dropbear() {
  if [ -x "$BIN_DROPBEAR" ]; then echo "$BIN_DROPBEAR"; return 0; fi
  if [ -n "$SYS_DROPBEAR" ]; then echo "$SYS_DROPBEAR"; return 0; fi
  return 1
}
lan_ip() {
  # Uu tien IP WiFi that, bo qua loopback.
  ip -4 addr show 2>/dev/null | awk '/inet / && $2 !~ /^127\./ {sub(/\/.*/, "", $2); print $2; exit}'
  if [ -z "$?" ] || [ -z "$(ip -4 addr show 2>/dev/null)" ]; then
    ifconfig 2>/dev/null | awk '/inet addr:/ && $0 !~ /127\.0\.0\.1/ {sub(/.*:/, "", $2); print $2; exit}'
  fi
}
running_pid() {
  [ -f "$PIDF" ] || return 1
  p="$(cat "$PIDF" 2>/dev/null | tr -d ' \r\n')"
  [ -n "$p" ] && kill -0 "$p" 2>/dev/null || return 1
  echo "$p"
}
cmd_status() {
  p="$(running_pid)" || { echo "stopped"; return 1; }
  i="$(lan_ip)"
  [ -n "$i" ] || i="?"
  echo "running pid=$p port=$PORT ip=$i"
  return 0
}
cmd_ip() { lan_ip; }
cmd_start() {
  if p="$(running_pid)"; then
    echo "dang chay pid=$p port=$PORT"
    lan_ip > "$IPFILE" 2>/dev/null
    return 0
  fi
  DB="$(pick_dropbear)" || {
    echo "thieu dropbear: chua co bin/dropbear va he thong khong co san." >&2
    echo "chay sh net-survey.sh de kiem tra, roi build theo bin/README.txt" >&2
    return 1
  }
  # Sinh host-key 1 lan duy nhat, giu trong data/ (song sot qua OTA).
  if [ ! -f "$KEYF" ]; then
    if command -v dropbearkey >/dev/null 2>&1; then
      dropbearkey -t ed25519 -f "$KEYF" >> "$LOG" 2>&1 || rm -f "$KEYF"
    elif [ -x "$APP/bin/dropbearkey" ]; then
      "$APP/bin/dropbearkey" -t ed25519 -f "$KEYF" >> "$LOG" 2>&1 || rm -f "$KEYF"
    fi
  fi
  # Khoa public cua nguoi ho tro (ban copy file authorized_keys vao data/).
  KEYS_ARG=""
  [ -f "$AUTHKEYS" ] && KEYS_ARG="-a $AUTHKEYS"
  rm -f "$PIDF"
  # Chay nen that su: setsid + nohup de song sot khi launch.sh thoat ve menu.
  if command -v setsid >/dev/null 2>&1; then
    if [ -f "$KEYF" ]; then
      setsid nohup "$DB" -p "$PORT" -r "$KEYF" $KEYS_ARG -P "$PIDF" >> "$LOG" 2>&1 &
    else
      setsid nohup "$DB" -p "$PORT" $KEYS_ARG -P "$PIDF" >> "$LOG" 2>&1 &
    fi
  else
    if [ -f "$KEYF" ]; then
      nohup "$DB" -p "$PORT" -r "$KEYF" $KEYS_ARG -P "$PIDF" >> "$LOG" 2>&1 &
    else
      nohup "$DB" -p "$PORT" $KEYS_ARG -P "$PIDF" >> "$LOG" 2>&1 &
    fi
  fi
  sleep 1
  if p="$(running_pid)"; then
    i="$(lan_ip)"; [ -n "$i" ] || i="?"
    echo "$i" > "$IPFILE" 2>/dev/null
    {
      echo "dropbear pid=$p port=$PORT ip=$i"
      echo "ssh root@$i -p $PORT   (mat khau root cua may)"
      echo "scp -P $PORT root@$i:/mnt/SDCARD/Logs/ ./  (copy log ve)"
    } | tee -a "$LOG"
    return 0
  fi
  echo "khong khoi dong duoc dropbear, xem $LOG" >&2
  tail -n 20 "$LOG" 2>/dev/null >&2
  return 1
}
cmd_stop() {
  p="$(running_pid)" || { echo "da dung san"; rm -f "$PIDF"; return 0; }
  kill "$p" 2>/dev/null
  sleep 1
  kill -9 "$p" 2>/dev/null
  rm -f "$PIDF"
  echo "da tat pid=$p"
}
case "${1:-status}" in
  start) cmd_start;; stop) cmd_stop;; restart) cmd_stop; sleep 1; cmd_start;;
  status) cmd_status;; ip) cmd_ip;; *) echo "dung: $0 start|stop|restart|status|ip" >&2; exit 2;;
esac
