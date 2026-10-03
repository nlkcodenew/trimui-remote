# Changelog — Trimui-Remote

## v0.3.0

- **Sửa crash khi mở app**: nguyên nhân là stock OS không có sẵn `dropbear` mà app
  chưa đóng gói binary → `remote.sh start` thất bại, `launch.sh` thoát ngay.
  Nay đóng gói sẵn `bin/dropbear` + `bin/dbclient` + `bin/dropbearkey` (static
  aarch64, build bằng GitHub Actions + `zig cc -target aarch64-linux-musl`).
- **Màn hình thông tin khi mở app** (đúng yêu cầu): hiện địa chỉ SSH LAN, địa chỉ
  SSH Internet (Pinggy), user `root` + mật khẩu, lệnh copy log, lệnh tắt.
  Dùng chung binary `trimui-terminal` để hiển thị (không tốn thêm RAM thường trực).
- `launch.sh` không còn báo “đã bật” giả khi start thất bại; tunnel Internet tự bật
  cùng lúc (tắt bằng `REMOTE_NO_TUNNEL=1`).
- **Tắt OTA tự động** vì repo đang private (manifest không tải được, chỉ ghi log
  `failed`). Muốn bật lại sau khi public repo: mở app với `REMOTE_OTA=1`.

## v0.2.0

- **SSH qua Internet bằng Pinggy** (không cần VPS): `tunnel.sh start/stop/status/log`.
- Tunnel reverse-SSH `−R0:localhost:2222` ra `a.pinggy.io:443`, Pinggy cấp địa chỉ
  công cộng `tcp://...` — dev ở xa SSH thẳng vào máy game.
- Vòng lặp tự reconnect khi rớt mạng, tốn thêm ~1MB RAM (vẫn dưới 5MB tổng nền).
- Sẵn sàng chuyển sang VPS sau này qua `data/tunnel.conf` (`MODE=vps`, port cố định).
- README viết lại đầy đủ tiếng Việt có dấu, thêm `docs/TUNNEL_PINGGY.md`.

## v0.1.0

- Bản đầu tiên: SSH LAN qua `dropbear`, port 2222.
- `launch.sh` toggle bật/tắt, thoát ngay để nhẹ RAM; daemon sống nhờ setsid+nohup.
- `remote.sh start/stop/restart/status/ip`, host-key sinh 1 lần trong `data/`.
- `net-survey.sh` thu thập thông tin mạng/SSH (gửi log về để build binary).
- `collect-logs.sh` đóng gói 1 file tgz để scp.
- OTA nền + đóng gói `make_release.py` / `verify_release.py` theo chuẩn Trimui-Terminal.
