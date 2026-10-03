#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Do workflow dropbear-static chay xong (timeout ~9 phut) roi goi fetch_dropbear.py."""
import subprocess
import sys
import time
import urllib.request
import urllib.error
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OWNER = "nlkcodenew"
REPO = "trimui-remote"
WF = sys.argv[1] if len(sys.argv) > 1 else "dropbear"

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
                                          "User-Agent": "trimui-remote-wait"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        return {"_err": e.code}

def main():
    tok = token()
    if not tok:
        print("FAIL: khong lay duoc token")
        return 1
    for i in range(27):
        data = api("/repos/%s/%s/actions/runs?per_page=5" % (OWNER, REPO), tok)
        runs = data.get("workflow_runs", []) if isinstance(data, dict) else []
        cand = [r for r in runs if WF in (r.get("name", ""))]
        cand.sort(key=lambda r: r.get("run_number", 0), reverse=True)
        run = cand[0] if cand else None
        if run:
            print("run %s status=%s conclusion=%s" % (run.get("id"), run.get("status"), run.get("conclusion")))
            if run.get("status") == "completed":
                if run.get("conclusion") != "success":
                    print("FAIL: workflow ket thuc voi %s" % run.get("conclusion"))
                    return 1
                print("BUILD XONG")
                return 0
        else:
            print("cho workflow xuat hien...")
        time.sleep(20)
    print("TIMEOUT: het 9 phut van chua xong")
    return 2

if __name__ == "__main__":
    sys.exit(main())
