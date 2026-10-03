#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Dung VPS jump-host cho Trimui-Remote (chay tren PC dev, KHONG chay tren may game).
- Tao user han che `trimui` (khoa password, chi login bang key rieng).
- Nap public-key tunnel voi gioi han: chi duoc reverse-forward
  127.0.0.1:22223 (permitlisten), cam pty/agent/X11.
- Kiem tra key login + reverse-forward that.

Dung:
  python3 tools/setup_vps.py --pem PATH_TO_YOUR_PEM --pub <file.pub> [--host YOUR_VPS_IP] [--user ubuntu] [--rport 22223]
Khoa PEM goc KHONG bao gio copy len may game.
"""
import argparse
import subprocess
import sys

def sh(cmd, **kw):
    p = subprocess.run(cmd, capture_output=True, text=True, **kw)
    return p.returncode, (p.stdout or "").strip(), (p.stderr or "").strip()[-2000:]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pem", required=True)
    ap.add_argument("--pub", required=True)
    ap.add_argument("--host", default="YOUR_VPS_IP")
    ap.add_argument("--user", default="ubuntu")
    ap.add_argument("--tuser", default="trimui")
    ap.add_argument("--rport", default="22223")
    a = ap.parse_args()

    with open(a.pub, encoding="utf-8") as h:
        pub = h.read().strip().split("\n")[0]
    if not pub.startswith("ssh-ed25519 "):
        print("FAIL: pubkey khong phai ssh-ed25519")
        return 1
    ssh = ["ssh", "-i", a.pem, "-o", "BatchMode=yes", "-o", "ConnectTimeout=15",
           "-o", "StrictHostKeyChecking=accept-new", "%s@%s" % (a.user, a.host)]
    scp = ["scp", "-i", a.pem, "-o", "BatchMode=yes",
           "-o", "StrictHostKeyChecking=accept-new"]

    print("== 1. copy pubkey len VPS ==")
    rc, out, err = sh(scp + [a.pub, "%s@%s:/tmp/trimui-tunnel.pub" % (a.user, a.host)])
    if rc != 0:
        print("FAIL scp: %s" % err); return 1
    print("ok")

    print("== 2. tao user + nap key han che ==")
    setup = (
        "set -e; "
        "id {tu} >/dev/null 2>&1 || sudo useradd -m -s /bin/bash -p '!' {tu}; "
        "sudo -u {tu} mkdir -p /home/{tu}/.ssh; sudo chmod 700 /home/{tu}/.ssh; "
        "PUB=$(cat /tmp/trimui-tunnel.pub); "
        "printf '%s' \"no-pty,no-agent-forwarding,no-X11-forwarding,permitlisten=\\\"127.0.0.1:{rp}\\\" $PUB\" "
        "| sudo tee /home/{tu}/.ssh/authorized_keys >/dev/null; "
        "sudo chmod 600 /home/{tu}/.ssh/authorized_keys; "
        "sudo chown -R {tu}:{tu} /home/{tu}/.ssh; rm -f /tmp/trimui-tunnel.pub; "
        "echo SETUP_OK"
    ).format(tu=a.tuser, rp=a.rport)
    rc, out, err = sh(ssh + [setup])
    print(out[-500:] if out else err)
    if rc != 0 or "SETUP_OK" not in out:
        print("FAIL setup"); return 1

    print("== 3. kiem tra login bang key tunnel ==")
    tssh = ["ssh", "-i", a.pub.replace(".pub", ""), "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=15", "-o", "StrictHostKeyChecking=accept-new",
            "%s@%s" % (a.tuser, a.host), "echo KEY_OK"]
    rc, out, err = sh(tssh)
    print(out if out else err)
    if rc != 0 or "KEY_OK" not in out:
        print("FAIL key login"); return 1

    print("== 4. kiem tra reverse-forward that ==")
    # Mo -N -R nen, kiem tra VPS co lang nghe 127.0.0.1:RPORT khong, roi tat.
    tun = subprocess.Popen(
        ["ssh", "-i", a.pub.replace(".pub", ""), "-o", "BatchMode=yes",
         "-o", "ConnectTimeout=15", "-o", "StrictHostKeyChecking=accept-new",
         "-N", "-R", "%s:localhost:22" % a.rport, "%s@%s" % (a.tuser, a.host)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        import time
        time.sleep(6)
        rc, out, err = sh(ssh + ["ss -ltn | grep 127.0.0.1:%s || ss -ltn | grep :%s" % (a.rport, a.rport)])
        print(out if out else "(khong thay port - FAIL)")
        ok = (":%s" % a.rport) in out
    finally:
        tun.terminate()
    if not ok:
        print("FAIL forward"); return 1
    print("VPS OK: user=%s rport=%s (Brick Pro giu port nay)" % (a.tuser, a.rport))
    return 0

if __name__ == "__main__":
    sys.exit(main())
