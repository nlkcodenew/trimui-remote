#!/bin/sh
# tunnel.sh: SSH nguoc ra Internet, sieu nhe (~1MB RAM).
#   sh tunnel.sh start   - mo tunnel (mac dinh Pinggy, khong can VPS)
#   sh tunnel.sh stop    - tat tunnel
#   sh tunnel.sh status  - con song khong + xem endpoint cong cong
#   sh tunnel.sh log     - xem log de lay dia chi tcp://... Pinggy cap
#   sh tunnel.sh restart - tat roi mo lai
# Cau hinh: $APP/data/tunnel.conf (tu tao tu tunnel.conf.example lan dau).
# Sau nay co VPS: sua MODE=vps + thong tin VPS trong file do.
case "$0" in */*) cd "$(dirname "$0")" || exit 1;; esac
APP="$(pwd)"
DATA="$APP/data"
CONF="$DATA/tunnel.conf"
PIDF="$DATA/tunnel.pid"
LOOPF="$DATA/tunnel-loop.sh"
TLOG="$DATA/tunnel.log"
PORT="${REMOTE_PORT:-2222}"

mkdir -p "$DATA" 2>/dev/null
if [ ! -f "$CONF" ]; then
  if [ -f "$APP/tunnel.conf" ]; then
    cp "$APP/tunnel.conf" "$CONF" 2>/dev/null
  elif [ -f "$APP/tunnel.conf.example" ]; then
    cp "$APP/tunnel.conf.example" "$CONF" 2>/dev/null
  else
    printf 'MODE=pinggy\n' > "$CONF" 2>/dev/null
  fi
fi
# Doc cau hinh (chi cac bien biet truoc, tranh thuc thi code la).
MODE=pinggy; PINGGY_HOST=a.pinggy.io; PINGGY_PORT=443; PINGGY_USER=tcp
VPS_HOST=""; VPS_PORT=22; VPS_USER=root; VPS_RPORT=12222
if [ -f "$CONF" ]; then
  # shellcheck disable=SC1090
  . "$CONF" 2>/dev/null
fi
[ -n "$MODE" ] || MODE=pinggy

pick_client() {
  if [ -x "$APP/bin/dbclient" ]; then echo "$APP/bin/dbclient|dbclient"; return 0; fi
  if command -v dbclient >/dev/null 2>&1; then echo "dbclient|dbclient"; return 0; fi
  if command -v ssh >/dev/null 2>&1; then echo "ssh|ssh"; return 0; fi
  return 1
}
running_pid() {
  [ -f "$PIDF" ] || return 1
  p="$(cat "$PIDF" 2>/dev/null | tr -d ' \r\n')"
  [ -n "$p" ] && kill -0 "$p" 2>/dev/null || return 1
  echo "$p"
}
kill_pat() {
  # Diet tien trinh con sot theo pattern (BusyBox khong chac co pkill).
  pat="$1"
  if command -v pkill >/dev/null 2>&1; then pkill -f "$pat" 2>/dev/null; return 0; fi
  ps 2>/dev/null | grep -F "$pat" | grep -v grep | awk '{print $1}' | while read -r k; do
    [ -n "$k" ] && kill "$k" 2>/dev/null
  done
}
show_endpoint() {
  # Pinggy in dia chi dang tcp://xxx:port trong log.
  grep -a -o -e 'tcp://[^ "]*' "$TLOG" 2>/dev/null | tail -n 1
}
cmd_status() {
  p="$(running_pid)" || { echo "tunnel stopped (mode=$MODE)"; return 1; }
  ep="$(show_endpoint)"
  echo "tunnel running pid=$p mode=$MODE"
  if [ -n "$ep" ]; then
    h="${ep#tcp://}"; host="${h%:*}"; tport="${h##*:}"
    echo "public: $ep"
    echo "ssh root@$host -p $tport   (mat khau root cua may game)"
  else
    echo "dang cho Pinggy cap dia chi... chay '$0 log' de xem"
  fi
  return 0
}
cmd_log() {
  [ -f "$TLOG" ] || { echo "chua co log"; return 1; }
  tail -n 30 "$TLOG" 2>/dev/null
}
cmd_endpoint() {
  # Chi in dia chi tcp:// (rong neu chua co) - cho show-status.sh goi.
  [ -f "$TLOG" ] || return 1
  show_endpoint
}
build_cmd() {
  # $1 = kieu client (dbclient|ssh). In cau lenh tunnel ra stdout.
  c="$1"
  # Khoa tunnel: dbclient (dropbear) khong doc duoc OpenSSH PEM -> convert 1 lan.
  KEYARG=""
  if [ "$MODE" = "vps" ] || [ "$MODE" = "pinggy" ]; then
    KEY="$DATA/tunnel_key"
    if [ -f "$KEY" ]; then
      chmod 600 "$KEY" 2>/dev/null
      if [ "$c" = "dbclient" ] && head -n 1 "$KEY" 2>/dev/null | grep -q OPENSSH; then
        if [ -x "$APP/bin/dropbearconvert" ]; then
          "$APP/bin/dropbearconvert" openssh dropbear "$KEY" "$DATA/tunnel_key.db" >> "$TLOG" 2>&1 \
            && chmod 600 "$DATA/tunnel_key.db" 2>/dev/null \
            && KEY="$DATA/tunnel_key.db"
        else
          echo "key OpenSSH nhung thieu dropbearconvert (client dbclient)" >> "$TLOG" 2>&1
        fi
      fi
      KEYARG="-i $KEY"
    fi
  fi
  if [ "$MODE" = "vps" ]; then
    [ -n "$VPS_HOST" ] || { echo "chua cau hinh VPS trong $CONF" >&2; return 1; }
    if [ "$c" = "dbclient" ]; then
      echo "dbclient -p $VPS_PORT -R $VPS_RPORT:localhost:$PORT -N -T -y -K 30 $KEYARG $VPS_USER@$VPS_HOST"
    else
      echo "ssh -p $VPS_PORT -R $VPS_RPORT:localhost:$PORT -N -T -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes $KEYARG $VPS_USER@$VPS_HOST"
    fi
  else
    # Pinggy TCP tunnel: Pinggy tu cap port cong cong ngau nhien (-R0).
    if [ "$c" = "dbclient" ]; then
      echo "dbclient -p $PINGGY_PORT -R 0:localhost:$PORT -N -T -y -K 30 $PINGGY_USER@$PINGGY_HOST"
    else
      echo "ssh -p $PINGGY_PORT -R 0:localhost:$PORT -N -T -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes $PINGGY_USER@$PINGGY_HOST"
    fi
  fi
}
cmd_start() {
  if p="$(running_pid)"; then echo "tunnel dang chay pid=$p"; cmd_status; return 0; fi
  # SSH LAN phai chay truoc: tunnel forward ve port dropbear tren may.
  if ! sh "$APP/remote.sh" status >/dev/null 2>&1; then
    echo "bat SSH LAN truoc..."
    sh "$APP/remote.sh" start || return 1
  fi
  PC="$(pick_client)" || {
    echo "thieu ssh client: khong co dbclient hay ssh." >&2
    echo "chay sh net-survey.sh de kiem tra, build theo bin/README.txt" >&2
    return 1
  }
  # PC dang "duong-dan|loai": tach dung (##*| lay sau |, %%|* lay truoc |).
  ctype="${PC##*|}"; cbin="${PC%%|*}"
  # Nap khoa tunnel vao data/ lan dau TRUOC khi build lenh (khoa theo may
  # trong ZIP, data/ song sot qua OTA).
  if [ ! -f "$DATA/tunnel_key" ] && [ -f "$APP/tunnel_key" ]; then
    cp "$APP/tunnel_key" "$DATA/tunnel_key" 2>/dev/null
    chmod 600 "$DATA/tunnel_key" 2>/dev/null
  fi
  TUNCMD="$(build_cmd "$ctype")" || return 1
  # Dung binary trong app theo duong dan tuyet doi (PATH luc chay nen thieu).
  case "$ctype" in
    dbclient)
      if [ -x "$APP/bin/dbclient" ]; then
        TUNCMD="$APP/bin/${TUNCMD#dbclient }"
      elif [ -x "$cbin" ] && [ "$cbin" != "dbclient" ]; then
        TUNCMD="$cbin/${TUNCMD#dbclient }"
      fi
      ;;
  esac
  cat > "$LOOPF" <<EOF
#!/bin/sh
# tu sinh boi tunnel.sh - dung sua tay
while :; do
  echo "--- \$(date '+%Y-%m-%d %H:%M:%S') chay: $TUNCMD" >> "$TLOG" 2>&1
  $TUNCMD >> "$TLOG" 2>&1
  echo "--- mat ket noi, thu lai sau 5s" >> "$TLOG" 2>&1
  sleep 5
done
EOF
  chmod +x "$LOOPF" 2>/dev/null
  rm -f "$PIDF"
  : >> "$TLOG" 2>/dev/null
  if command -v setsid >/dev/null 2>&1; then
    setsid nohup sh "$LOOPF" >> "$TLOG" 2>&1 &
  else
    nohup sh "$LOOPF" >> "$TLOG" 2>&1 &
  fi
  echo $! > "$PIDF" 2>/dev/null
  sleep 3
  if p="$(running_pid)"; then
    echo "da mo tunnel pid=$p mode=$MODE"
    echo "cho Pinggy cap dia chi (5-15s), xem bang: sh tunnel.sh log"
    return 0
  fi
  echo "khong mo duoc tunnel, xem $TLOG" >&2
  return 1
}
cmd_stop() {
  p="$(running_pid)" || { echo "tunnel da dung san"; rm -f "$PIDF"; return 0; }
  kill "$p" 2>/dev/null
  sleep 1
  kill -9 "$p" 2>/dev/null
  rm -f "$PIDF" "$LOOPF"
  # Diet client con sot (dbclient/ssh treo).
  kill_pat "pinggy.io"
  [ "$MODE" = "vps" ] && [ -n "$VPS_HOST" ] && kill_pat "$VPS_HOST"
  echo "da tat tunnel pid=$p"
}
case "${1:-status}" in
  start) cmd_start;; stop) cmd_stop;; restart) cmd_stop; sleep 1; cmd_start;;
  status) cmd_status;; log) cmd_log;; endpoint) cmd_endpoint;; *) echo "dung: $0 start|stop|restart|status|log|endpoint" >&2; exit 2;;
esac
