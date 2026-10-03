#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Xoa TOAN BO releases cu tren GitHub (mot lan, truoc khi public).
Ly do: asset ZIP cu chua files/tunnel.conf that.
Token lay tu Windows credential manager, khong in ra log.
"""
import json
import subprocess
import sys
import urllib.request
import urllib.error

OWNER = "nlkcodenew"
REPO = "trimui-remote"

def token():
    p = subprocess.run(["git", "credential", "fill"],
                       input="url=https://github.com\n\n",
                       capture_output=True, text=True)
    for line in (p.stdout or "").splitlines():
        if line.startswith("password="):
            return line[len("password="):].strip()
    return ""

def api(method, path, tok):
    req = urllib.request.Request("https://api.github.com" + path,
                                 method=method,
                                 headers={"Authorization": "Bearer " + tok,
                                          "Accept": "application/vnd.github+json",
                                          "User-Agent": "trimui-remote-cleanup"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            raw = r.read().decode() or "[]"
            return r.status, json.loads(raw)
    except urllib.error.HTTPError as e:
        return e.code, {"raw": e.read().decode(errors="replace")[:300]}

def main():
    tok = token()
    if not tok:
        print("FAIL: khong lay duoc token")
        return 1
    st, rels = api("GET", "/repos/%s/%s/releases?per_page=50" % (OWNER, REPO), tok)
    if st != 200:
        print("FAIL list releases: %s %s" % (st, rels))
        return 1
    if not rels:
        print("khong co release nao")
        return 0
    for r in rels:
        rid, tag = r["id"], r.get("tag_name")
        st2, _ = api("DELETE", "/repos/%s/%s/releases/%s" % (OWNER, REPO, rid), tok)
        print(("DELETED " if st2 == 204 else "FAIL %s " % st2) + "id=%s tag=%s" % (rid, tag))
    return 0

if __name__ == "__main__":
    sys.exit(main())
