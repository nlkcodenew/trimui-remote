#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tao manifest + ZIP cai dat cho trimui-remote.
ZIP co cau truc Apps/TrimuiRemote/ de giai nen thang vao goc the nho.
Copy y tuong tu Trimui-Terminal/tools/make_release.py, rut gon cho app shell-only.
"""
import hashlib
import json
import os
import shutil
import zipfile
from datetime import datetime, timedelta, timezone
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES_DIR = os.path.join(ROOT, "files")
MANIFEST_PATH = os.path.join(ROOT, "manifest.json")
DIST_DIR = os.path.join(ROOT, "dist")
VERSION_FILE = os.path.join(ROOT, "VERSION")
TZ = timezone(timedelta(hours=7))
APP_DIR_IN_ZIP = "Apps/TrimuiRemote"
EXCLUDE_NAMES = {"__pycache__", ".update_staging", "data"}
EXCLUDE_FILES = {"desktop.ini", ".DS_Store", "tunnel.conf"}
# tunnel.conf that chua thong tin VPS that (neu co) - KHONG dong goi, KHONG commit.
# May game tu dung tunnel.conf.example (pinggy mac dinh) khi thieu file nay.
RUNTIME_PREFIXES = ("Remote-launcher.log", "Remote-ota.log", "Remote-debug.log",
                    "Net-survey-", "debug-")
LF_EXTS = {".json", ".md", ".py", ".sh", ".txt", ".cmake", ".yml", ".yaml"}

def app_version():
    with open(VERSION_FILE, encoding="utf-8") as f:
        return f.read().strip().strip("vV")

def sync_files_version(version):
    target = os.path.join(FILES_DIR, "VERSION")
    data = ("%s\n" % version).encode("ascii")
    old = None
    if os.path.isfile(target):
        with open(target, "rb") as h:
            old = h.read()
    if old != data:
        with open(target, "wb") as h:
            h.write(data)
        print("synced files/VERSION -> %s" % version)

def sha256(data):
    return hashlib.sha256(data).hexdigest()

def release_bytes(path):
    with open(path, "rb") as h:
        data = h.read()
    if os.path.splitext(path)[1].lower() in LF_EXTS:
        data = data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    return data

def excluded(name):
    return (name in EXCLUDE_FILES or name.startswith(".") or name.endswith(".pyc")
            or any(name.startswith(p) for p in RUNTIME_PREFIXES))

def archive_add(archive, source, target, executable=False):
    data = release_bytes(source)
    info = zipfile.ZipInfo(target, date_time=(2020, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.create_system = 3
    info.external_attr = (0o100755 if executable else 0o100644) << 16
    archive.writestr(info, data)

def main():
    version = app_version()
    print("APP_VERSION = %s" % version)
    sync_files_version(version)
    files = []
    total = 0
    for cur, dirs, names in os.walk(FILES_DIR):
        dirs[:] = sorted(d for d in dirs if d not in EXCLUDE_NAMES)
        for fn in sorted(names):
            if excluded(fn):
                continue
            fp = os.path.join(cur, fn)
            rel = os.path.relpath(fp, FILES_DIR).replace(os.sep, "/")
            data = release_bytes(fp)
            files.append({"path": rel, "sha256": sha256(data), "size": len(data)})
            total += len(data)
            print("  %s (%d bytes)" % (rel, len(data)))
    print("total: %d file(s), %d bytes" % (len(files), total))
    shutil.rmtree(DIST_DIR, ignore_errors=True)
    os.makedirs(DIST_DIR, exist_ok=True)
    archive_name = "trimui-remote-v%s.zip" % version
    archive_path = os.path.join(DIST_DIR, archive_name)
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for cur, dirs, names in os.walk(FILES_DIR):
            dirs[:] = sorted(d for d in dirs if d not in EXCLUDE_NAMES)
            for fn in sorted(names):
                if excluded(fn):
                    continue
                src = os.path.join(cur, fn)
                rel = os.path.relpath(src, FILES_DIR).replace(os.sep, "/")
                exe = rel.endswith(".sh") or rel.startswith("bin/") or rel == "launch.sh"
                archive_add(archive, src, "%s/%s" % (APP_DIR_IN_ZIP, rel), exe)
    with open(archive_path, "rb") as h:
        checksum = sha256(h.read())
    with open(archive_path + ".sha256", "w", encoding="ascii", newline="\n") as h:
        h.write("%s  %s\n" % (checksum, archive_name))
    manifest = {
        "version": version,
        "app": "trimui-remote",
        "built": datetime.now(TZ).replace(microsecond=0).isoformat(),
        "files": files,
        "release_asset": {"name": archive_name, "sha256": checksum,
                           "size": os.path.getsize(archive_path)},
    }
    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("wrote %s + %s" % (archive_path, MANIFEST_PATH))

if __name__ == "__main__":
    main()
