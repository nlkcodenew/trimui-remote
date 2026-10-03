#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Gate truoc khi release trimui-remote: app shell-only, sieu nhe.
v0.1 chua bat buoc binary (dropbear build sau) -> chi WARN neu thieu,
nhung khi da co binary thi phai la ELF AArch64.
"""
import json
import os
import sys
import zipfile
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST = os.path.join(ROOT, "dist")
FAIL = []
WARN = []

def check(cond, msg):
    print(("PASS " if cond else "FAIL ") + msg)
    if not cond:
        FAIL.append(msg)

def warn(cond, msg):
    print(("PASS " if cond else "WARN ") + msg)
    if not cond:
        WARN.append(msg)

def main():
    with open(os.path.join(ROOT, "VERSION"), encoding="utf-8") as h:
        version = h.read().strip().strip("vV")
    check(os.path.isfile(os.path.join(ROOT, "files", "launch.sh")), "launch.sh ton tai")
    check(os.path.isfile(os.path.join(ROOT, "files", "remote.sh")), "remote.sh ton tai")
    check(os.path.isfile(os.path.join(ROOT, "files", "show-status.sh")), "show-status.sh ton tai")
    check(os.path.isfile(os.path.join(ROOT, "files", "tunnel.sh")), "tunnel.sh ton tai")
    check(os.path.isfile(os.path.join(ROOT, "files", "tunnel.conf.example")), "tunnel.conf.example ton tai")
    check(os.path.isfile(os.path.join(ROOT, "files", "net-survey.sh")), "net-survey.sh ton tai")
    check(os.path.isfile(os.path.join(ROOT, "files", "collect-logs.sh")), "collect-logs.sh ton tai")
    check(os.path.isfile(os.path.join(ROOT, "files", "config.json")), "config.json ton tai")
    check(os.path.isfile(os.path.join(ROOT, "files", "icon.png")), "icon.png ton tai")
    shipped = os.path.join(ROOT, "files", "VERSION")
    shipped_version = open(shipped, encoding="utf-8").read().strip() if os.path.isfile(shipped) else ""
    check(shipped_version == version, "files/VERSION khop VERSION (%r)" % shipped_version)
    cfg = json.load(open(os.path.join(ROOT, "files", "config.json"), encoding="utf-8"))
    check(cfg.get("launch") == "launch.sh", "config.json tro dung launch.sh")
    for sh in ("launch.sh", "remote.sh", "tunnel.sh", "show-status.sh", "net-survey.sh", "collect-logs.sh"):
        p = os.path.join(ROOT, "files", sh)
        if os.path.isfile(p):
            with open(p, "rb") as h:
                head = h.read(2)
            check(head == b"#!", "%s co shebang" % sh)
    # remote.sh phai co du 4 lenh + chay nen that (setsid/nohup), khong giu UI nang.
    r = open(os.path.join(ROOT, "files", "remote.sh"), encoding="utf-8", errors="replace").read()
    for kw in ("cmd_start", "cmd_stop", "running_pid", "nohup", "2222"):
        check(kw in r, "remote.sh chua %s" % kw)
    check("python" not in r.lower() and "SDL" not in r, "remote.sh thuan shell, khong keo Python/SDL")
    t = open(os.path.join(ROOT, "files", "tunnel.sh"), encoding="utf-8", errors="replace").read()
    for kw in ("PINGGY_HOST", "tunnel-loop", "MODE=vps", "VPS_RPORT"):
        check(kw in t, "tunnel.sh chua %s" % kw)
    check("tailscale" not in t.lower(), "tunnel.sh khong keo Tailscale (giu nhe)")
    s = open(os.path.join(ROOT, "files", "show-status.sh"), encoding="utf-8", errors="replace").read()
    for kw in ("wait_endpoint", "STATUS.txt", "Pinggy"):
        check(kw in s, "show-status.sh chua %s" % kw)
    l = open(os.path.join(ROOT, "files", "launch.sh"), encoding="utf-8", errors="replace").read()
    for kw in ("show-status.sh", "REMOTE_OTA", "remote.sh"):
        check(kw in l, "launch.sh chua %s" % kw)
    check("TrimuiTerminal" not in l, "launch.sh khong phu thuoc Terminal (chay an v0.4)")
    # Binary: BAT BUOC tu v0.3 (stock OS khong co san dropbear).
    for b in ("bin/dropbear", "bin/dbclient", "bin/dropbearkey", "bin/dropbearconvert"):
        p = os.path.join(ROOT, "files", b)
        if os.path.isfile(p):
            with open(p, "rb") as h:
                magic = h.read(20)
            check(magic[:4] == b"\x7fELF", "%s la ELF" % b)
            check(int.from_bytes(magic[18:20], "little") == 0xB7, "%s la AArch64" % b)
        else:
            check(False, "%s bat buoc tu v0.3 (build bang CI dropbear-static)" % b)
    zips = [f for f in os.listdir(DIST) if f.endswith(".zip")] if os.path.isdir(DIST) else []
    if zips:
        zp = os.path.join(DIST, sorted(zips)[-1])
        names = zipfile.ZipFile(zp).namelist()
        check("Apps/TrimuiRemote/launch.sh" in names, "ZIP co Apps/TrimuiRemote/launch.sh")
        check("Apps/TrimuiRemote/remote.sh" in names, "ZIP co remote.sh")
        check(not any("secrets" in n for n in names), "ZIP khong chua secret")
    else:
        print("SKIP kiem tra ZIP (chua chay make_release.py)")
    if WARN:
        print("WARNINGS: %d (chap nhan duoc o v0.1)" % len(WARN))
    if FAIL:
        print("FAILED: %d" % len(FAIL))
        return 1
    print("ALL OK")
    return 0

if __name__ == "__main__":
    sys.exit(main())
