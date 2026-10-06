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
    # manifest.json la thu may doc trong OTA. Phai khop VERSION, neu khong
    # may se bao "da la ban moi nhat" ma ban moi chua duoc day len GitHub.
    mpath = os.path.join(ROOT, "manifest.json")
    if os.path.isfile(mpath):
        with open(mpath, encoding="utf-8") as h:
            man = json.load(h)
        check(man.get("version") == version,
              "manifest.json khop VERSION (manifest=%r)" % man.get("version"))
        paths = {e["path"] for e in man.get("files", [])}
        for req in ("VERSION", "ota-update.sh", "launch.sh"):
            check(req in paths, "manifest.json co %s" % req)
    cfg = json.load(open(os.path.join(ROOT, "files", "config.json"), encoding="utf-8"))
    check(cfg.get("launch") == "launch.sh", "config.json tro dung launch.sh")
    for sh in ("launch.sh", "remote.sh", "tunnel.sh", "show-status.sh", "screen.sh", "net-survey.sh", "collect-logs.sh"):
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
    check('ctype="${PC##*|}"' in t, "tunnel.sh tach loai client dung (##*|)")
    check("CBIN" in t and 'build_cmd "$ctype" "$CBIN"' in t, "tunnel.sh truyen duong dan binary truc tiep")
    check("${TUNCMD#dbclient" not in t, "tunnel.sh khong thay the chuoi binary (tung lam mat ten)")
    check(t.index("tunnel_key") < t.index('TUNCMD="$(build_cmd'), "tunnel.sh nap key TRUOC khi build lenh")
    check("tunnel-loop v$CURVER" in t, "tunnel.sh danh dau version loop (huy loop cu)")
    check("tailscale" not in t.lower(), "tunnel.sh khong keo Tailscale (giu nhe)")
    s = open(os.path.join(ROOT, "files", "show-status.sh"), encoding="utf-8", errors="replace").read()
    for kw in ("wait_endpoint", "STATUS.txt", "Pinggy"):
        check(kw in s, "show-status.sh chua %s" % kw)
    l = open(os.path.join(ROOT, "files", "launch.sh"), encoding="utf-8", errors="replace").read()
    for kw in ("show-status.sh", "remote-ui", "timeout 300"):
        check(kw in l, "launch.sh chua %s" % kw)
    check("REMOTE_RESTARTED" not in l, "launch.sh khong restart foreground (mo nhanh v0.6)")
    check("TrimuiTerminal" not in l, "launch.sh khong phu thuoc Terminal (UI rieng v0.5)")
    check(os.path.isfile(os.path.join(ROOT, "files", "assets", "font.ttf")),
          "assets/font.ttf ton tai (chu Viet co dau)")
    check(os.path.isfile(os.path.join(ROOT, "ui", "remote-ui.c")), "ui/remote-ui.c ton tai")
    # Binary: BAT BUOC tu v0.3 (stock OS khong co san dropbear).
    for b in ("bin/dropbear", "bin/dbclient", "bin/dropbearkey", "bin/dropbearconvert", "bin/remote-ui"):
        p = os.path.join(ROOT, "files", b)
        if os.path.isfile(p):
            with open(p, "rb") as h:
                magic = h.read(20)
            check(magic[:4] == b"\x7fELF", "%s la ELF" % b)
            check(int.from_bytes(magic[18:20], "little") == 0xB7, "%s la AArch64" % b)
        else:
            check(False, "%s bat buoc tu v0.3 (build bang CI dropbear-static)" % b)
    # dispctl: tieu chuc cho screen.sh khi da B-thoat. remote-ui (nut Y) van
    # tu tat den duoc, thieu dispctl thi screen.sh bao loi ro rang.
    p = os.path.join(ROOT, "files", "bin", "dispctl")
    if os.path.isfile(p):
        with open(p, "rb") as h:
            magic = h.read(20)
        check(magic[:4] == b"\x7fELF", "bin/dispctl la ELF")
        check(int.from_bytes(magic[18:20], "little") == 0xB7, "bin/dispctl la AArch64")
    else:
        warn(False, "bin/dispctl chua build (screen.sh can no; nut Y van dung)")
    zips = [f for f in os.listdir(DIST) if f.endswith(".zip")] if os.path.isdir(DIST) else []
    if zips:
        zp = os.path.join(DIST, sorted(zips)[-1])
        names = zipfile.ZipFile(zp).namelist()
        check("Apps/TrimuiRemote/launch.sh" in names, "ZIP co Apps/TrimuiRemote/launch.sh")
        check("Apps/TrimuiRemote/remote.sh" in names, "ZIP co remote.sh")
        check(not any("secrets" in n for n in names), "ZIP khong chua secret")
        check("Apps/TrimuiRemote/tunnel.conf" not in names,
              "ZIP khong ship tunnel.conf that (OTA an toan)")
        check("Apps/TrimuiRemote/tunnel_key" not in names,
              "ZIP khong ship private key (nap tay qua scp)")
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
