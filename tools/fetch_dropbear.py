#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tai artifact dropbear-aarch64-static tu GitHub Actions ve files/bin/.
Token lay tu Windows credential manager, khong in ra log.
Dung: python3 tools/fetch_dropbear.py  (lay run moi nhat thanh cong)
"""
import io
import os
import subprocess
import sys
import urllib.request
import urllib.error
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OWNER = "nlkcodenew"
REPO = "trimui-remote"
# (ten artifact, cac file lay ra files/bin/)
WANT = {
    "dropbear-aarch64-static": ("dropbear", "dbclient", "dropbearkey", "dropbearconvert"),
    "remote-ui-aarch64": ("remote-ui",),
}

def token():
    p = subprocess.run(["git", "credential", "fill"],
                       input="url=https://github.com\n\n",
                       capture_output=True, text=True, cwd=ROOT)
    for line in (p.stdout or "").splitlines():
        if line.startswith("password="):
            return line[len("password="):].strip()
    return ""

def api(path, tok):
    req = urllib.request.Request("https://api.github.com" + path,
                                 headers={"Authorization": "Bearer " + tok,
                                          "Accept": "application/vnd.github+json",
                                          "User-Agent": "trimui-remote-fetch"})
    with urllib.request.urlopen(req, timeout=60) as r:
        import json
        return json.loads(r.read().decode() or "{}")

def main():
    tok = token()
    if not tok:
        print("FAIL: khong lay duoc github token")
        return 1
    data = api("/repos/%s/%s/actions/artifacts?per_page=50" % (OWNER, REPO), tok)
    byname = {}
    for a in data.get("artifacts", []):
        if a.get("name") in WANT and not a.get("expired"):
            byname.setdefault(a["name"], []).append(a)
    for lst in byname.values():
        lst.sort(key=lambda a: a.get("updated_at", ""), reverse=True)
    missing = [n for n in WANT if n not in byname]
    if missing:
        print("FAIL: chua co artifact %s (cho workflow chay xong)" % ", ".join(missing))
        return 1
    bindir = os.path.join(ROOT, "files", "bin")
    os.makedirs(bindir, exist_ok=True)
    for name, files in WANT.items():
        art = byname[name][0]
        print("artifact %s id=%s size=%s updated=%s" % (name, art["id"], art["size_in_bytes"], art["updated_at"]))
        req = urllib.request.Request(
            "https://api.github.com/repos/%s/%s/actions/artifacts/%s/zip" % (OWNER, REPO, art["id"]),
            headers={"Authorization": "Bearer " + tok,
                     "Accept": "application/vnd.github+json",
                     "User-Agent": "trimui-remote-fetch"})
        # khong theo redirect tu dong voi header cu: GitHub tra 302 ve URL ky san.
        opener = urllib.request.build_opener(NoAuthRedirect())
        with opener.open(req, timeout=120) as r:
            blob = r.read()
        print("downloaded %d bytes" % len(blob))
        with zipfile.ZipFile(io.BytesIO(blob)) as z:
            for n in z.namelist():
                base = os.path.basename(n)
                if base in files and base == n.strip("/").split("/")[-1]:
                    with z.open(n) as src, open(os.path.join(bindir, base), "wb") as dst:
                        dst.write(src.read())
                    print("wrote files/bin/%s" % base)
        # chmod +x de ZIP giu quyen (make_release danh dau bin/ la executable).
        for b in files:
            p = os.path.join(bindir, b)
            if os.path.isfile(p):
                os.chmod(p, 0o755)
                print("ok %s (%d bytes)" % (b, os.path.getsize(p)))
            else:
                print("FAIL thieu %s trong artifact %s" % (b, name))
                return 1
    return 0

class NoAuthRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        r = super().redirect_request(req, fp, code, msg, headers, newurl)
        if r is not None:
            r.headers.pop("Authorization", None)
        return r

if __name__ == "__main__":
    sys.exit(main())
