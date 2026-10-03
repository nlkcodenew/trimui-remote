#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""In log cua job dropbear-static that bai (100 dong cuoi)."""
import subprocess
import sys
import urllib.request
import urllib.error
import json
import zipfile
import io

OWNER = "nlkcodenew"
REPO = "trimui-remote"
RUN = sys.argv[1] if len(sys.argv) > 1 else "37087250312"

def token():
    p = subprocess.run(["git", "credential", "fill"],
                       input="url=https://github.com\n\n",
                       capture_output=True, text=True)
    for line in (p.stdout or "").splitlines():
        if line.startswith("password="):
            return line[len("password="):].strip()
    return ""

tok = token()
req = urllib.request.Request(
    "https://api.github.com/repos/%s/%s/actions/runs/%s/logs" % (OWNER, REPO, RUN),
    headers={"Authorization": "Bearer " + tok, "Accept": "application/vnd.github+json",
             "User-Agent": "trimui-remote-log"})
class NoAuth(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        r = super().redirect_request(req, fp, code, msg, headers, newurl)
        if r is not None:
            r.headers.pop("Authorization", None)
        return r
blob = build_opener = urllib.request.build_opener(NoAuth()).open(req, timeout=120).read()
with zipfile.ZipFile(io.BytesIO(blob)) as z:
    for n in z.namelist():
        if "build" in n.lower():
            txt = z.read(n).decode(errors="replace").splitlines()
            # tim dong loi
            for i, l in enumerate(txt):
                if "error" in l.lower() or "curl:" in l.lower() or "failed" in l.lower():
                    print("\n".join(txt[max(0, i-3):i+4]))
                    print("-----")
                    break
            print("=== 25 dong cuoi ===")
            print("\n".join(txt[-25:]))
