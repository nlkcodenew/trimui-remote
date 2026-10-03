#!/bin/sh
# show-status.sh: in man hinh thong tin SSH (duoc TrimuiTerminal goi qua -r).
# Cho Pinggy cap dia chi toi da ~25s roi in tat ca, xong thoat
# (terminal giu shell interactive o lai de ban gõ lenh tiep).
#   sh show-status.sh              -> in ra man hinh
#   sh show-status.sh --file-only  -> chi ghi STATUS.txt (fallback)
case "$0" in */*) cd "$(dirname "$0")" || exit 1;; esac
APP="$(pwd)"
OUT="$APP/STATUS.txt"

wait_endpoint() {
  # Doi tcp:// xuat hien trong tunnel.log (Pinggy can 5-15s).
  n=0
  while [ "$n" -lt 25 ]; do
    ep="$(sh "$APP/tunnel.sh" endpoint 2>/dev/null)"
    if [ -n "$ep" ]; then printf '%s' "$ep"; return 0; fi
    # Tunnel chet giua chung thi dung doi.
    sh "$APP/tunnel.sh" status >/dev/null 2>&1 || return 1
    sleep 2
    n=$((n + 2))
  done
  return 1
}

LAN="$(sh "$APP/remote.sh" status 2>/dev/null || echo 'SSH LAN: CHUA CHAY')"
IP="$(sh "$APP/remote.sh" ip 2>/dev/null)"
[ -n "$IP" ] || IP="?"
TUN_RUN=0
sh "$APP/tunnel.sh" status >/dev/null 2>&1 && TUN_RUN=1
MODE=pinggy
[ -f "$APP/data/tunnel.conf" ] && . "$APP/data/tunnel.conf" 2>/dev/null
[ -n "$MODE" ] || MODE=pinggy

EP=""
if [ "$TUN_RUN" = "1" ] && [ "$1" != "--file-only" ]; then
  echo "Dang doi Pinggy cap dia chi Internet (toi da ~25s)..."
  EP="$(wait_endpoint)" || EP=""
elif [ "$TUN_RUN" = "1" ]; then
  EP="$(sh "$APP/tunnel.sh" endpoint 2>/dev/null)"
fi

{
echo "========================================"
echo "  TRIMUI REMOTE - thong tin SSH"
echo "========================================"
echo ""
echo "[1] SSH trong mang LAN (cung WiFi):"
echo "    Dia chi : $IP"
echo "    Lenh    : ssh root@$IP -p 2222"
echo "    Trang thai: $LAN"
echo ""
echo "    User    : root"
echo "    Pass    : mat khau root cua may"
echo ""
if [ "$MODE" = "vps" ]; then
  echo "[2] SSH qua Internet (VPS, port co dinh):"
else
  echo "[2] SSH qua Internet (Pinggy):"
fi
if [ -n "$EP" ]; then
  H="${EP#tcp://}"; HOST="${H%:*}"; TPORT="${H##*:}"
  echo "    Dia chi : $EP"
  echo "    Lenh    : ssh root@$HOST -p $TPORT"
  echo "    (port doi moi khi reconnect - xem lai o day)"
else
  if [ "$TUN_RUN" = "1" ]; then
    if [ "$MODE" = "vps" ]; then
      echo "    Dang mo tunnel... vai giay nua go: sh tunnel.sh log"
      echo "    tren PC: ssh trimui-brick  (user root)"
    else
      echo "    Dang cho Pinggy... go: sh tunnel.sh log"
    fi
  else
    echo "    CHUA BAT (mo lai app hoac: sh tunnel.sh start)"
  fi
fi
echo ""
echo "----------------------------------------"
echo "Copy log ve: sh collect-logs.sh"
echo "Tat SSH LAN: sh remote.sh stop"
echo "Tat Internet: sh tunnel.sh stop"
echo "Thoat man hinh nay: phim B 2 lan"
echo "----------------------------------------"
} | tee "$OUT"
