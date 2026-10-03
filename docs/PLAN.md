# Trimui-Remote — ke hoach (v0.1 truoc, v0.2 sau)

## Da chot voi user (2026-10-03)

- Nhe het suc, chay nen, RAM 1GB.
- Buoc 1: nguoi dung mo app -> dev SSH vao doc log debug. LAM NGAY.
- Buoc 2: chay nen de co-op retro 2 nguoi. DE SAU.
- Pham vi v0.1: SSH LAN + chuan bi SSH tu xa (khac mang). Khong Tailscale.

## v0.3 (sua crash + man hinh + binary san) — DANG LAM

- Nguyen nhan crash tren may that (log SD card): stock OS khong co dropbear,
  app chua dong goi binary -> start that bai, launch thoat ngay.
- Huong sua: CI build static dropbear/dbclient/dropbearkey, dong goi vao ZIP.
- Man hinh thong tin: dung chung trimui-terminal -r show-status.sh.
- OTA tat mac dinh khi repo private (REMOTE_OTA=1 de bat lai sau khi public).

1. `net-survey.sh` — chay tren ca Brick Pro + Smart Pro S, gui log ve.
   Quyet dinh: stock OS co san dropbear/sshd/dbclient/ssh khong?
2. `remote.sh start/stop/status` — dropbear nen, toggle qua `launch.sh`. XONG.
3. `collect-logs.sh` — dong goi 1 file tgz de scp. XONG.
4. Build `bin/dropbear` + `bin/dropbearkey` (+`dbclient`) static aarch64 (SDK TG5050).
   DANG CHO: can log net-survey de biet he thong co san gi.
5. `make_release.py` / `verify_release.py` -> ZIP `Apps/TrimuiRemote/`. XONG.
6. Test: mo app -> `ssh root@IP -p 2222` -> `sh collect-logs.sh` -> scp ve.

## v0.2 (SSH qua Internet bang Pinggy) — CODE XONG, CHO TEST

- `tunnel.sh start/stop/restart/status/log` + `tunnel.conf.example` + `docs/TUNNEL_PINGGY.md`.
- Khong Tailscale (ton 30-50MB RAM, di nguoc muc tieu nhe).
- Gioi han biet truoc: Pinggy free doi port moi reconnect + gioi han session.
- Test that can moi biet: port `-R0` co duoc cap khong, dbclient hay ssh chay duoc.

## v0.2+ (de sau: co-op retro 2 nguoi)

- Can research: netplay cua RetroArch (co san UDP), do tre, can hien IP doi thu.
- Luc nay moi danh gia lai Tailscale/WireGuard (can UDP + /dev/net/tun).
- Ket qua net-survey (muc tun) se quyet dinh co di Tailscale duoc khong.

## Ghi nho ky thuat

- 1 ban duy nhat cho ca 2 may (aarch64, pixel that — bai hoc Xiaozhi).
- Daemon song sot khi ve menu nho setsid+nohup, pid trong `data/`.
- OTA copy tu Terminal, doi REPO -> trimui-remote truoc khi release.
