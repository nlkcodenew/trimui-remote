#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tao repo GitHub private nlkcodenew/trimui-remote neu chua co.
Token lay tu Windows credential manager (git credential fill), khong in ra log.
"""
import json
import subprocess
import sys
import urllib.request
import urllib.error

OWNER = "nlkcodenew"
NAME = "trimui-remote"

def token():
    p = subprocess.run(["git", "credential", "fill"],
                       input="url=https://github.com\n\n",
                       capture_output=True, text=True)
    for line in (p.stdout or "").splitlines():
        if line.startswith("password="):
            return line[len("password="):].strip()
    return ""

def api(method, path, tok, data=None):
    url = "https://api.github.com" + path
    body = json.dumps(data).encode() if isinstance(data, dict) else data
    req = urllib.request.Request(url, data=body, method=method,
                                 headers={"Authorization": "Bearer " + tok,
                                          "Accept": "application/vnd.github+json",
                                          "User-Agent": "trimui-remote-setup"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        raw = e.read().decode(errors="replace")
        try:
            return e.code, json.loads(raw or "{}")
        except Exception:
            return e.code, {"raw": raw[:300]}

def main():
    tok = token()
    if not tok:
        print("FAIL: khong lay duoc github token tu credential manager")
        return 1
    st, repo = api("GET", "/repos/%s/%s" % (OWNER, NAME), tok)
    if st == 200:
        print("repo da ton tai: %s (private=%s)" % (repo.get("full_name"), repo.get("private")))
        return 0
    st, repo = api("POST", "/user/repos", tok,
                   {"name": NAME, "private": True,
                    "description": "SSH debug nhe + chay nen cho TrimUI Brick Pro / Smart Pro S (dropbear LAN, Pinggy Internet)",
                    "auto_init": False})
    if st not in (200, 201):
        print("FAIL tao repo: %s %s" % (st, repo))
        return 1
    print("created private repo: %s" % repo.get("full_name"))
    return 0

if __name__ == "__main__":
    sys.exit(main())
