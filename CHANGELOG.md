# Changelog — Trimui-Remote

## v0.6.0

- **Đổi cách tiếp cận mở app**: bỏ OTA foreground + tự restart (chờ tới 60 giây
  khiến launcher tưởng app treo nên diệt — nhìn như crash, trong khi chạy tay
  thì bình thường). OTA trở lại chạy **nền** như bản cũ: mở app lên màn hình ngay,
  có bản mới thì lần mở sau dùng.
- Giữ nguyên toàn bộ sửa lỗi tunnel (dbclient, nạp key, hủy loop cũ), chờ dropbear
  8 giây, tự `chmod +x`, xoay log, màn hình chữ to, thoát B có panel giữa.

## v0.5.4

- Tự chữa mất quyền thực thi: `launch.sh` tự `chmod +x` cho `bin/*` và `*.sh`
  mỗi lần mở (thẻ nhớ FAT không giữ quyền file, chép tay có thể mất).
- Xoay `tunnel.log`: chỉ giữ 200 dòng cuối mỗi lần mở tunnel, tránh file phình
  to vô hạn trên thẻ nhớ.

## v0.5.3

- Tự hủy tunnel-loop của bản cũ khi mở app bản mới (loop cũ giữ lệnh `ssh` sai nên
  giữ mãi cũng không nối được; nay `tunnel.sh start` so version trong loop và làm
  lại loop mới).

## v0.5.2

- Sửa tunnel không bao giờ nối được (`ssh: not found` lặp vô hạn): `tunnel.sh` tách
  nhầm loại client nên luôn dùng `ssh` hệ thống (vốn không có), thay vì `dbclient`
  đóng gói sẵn. Nay dùng đúng `$APP/bin/dbclient` theo đường dẫn tuyệt đối.
- Sửa khóa tunnel không tới được máy: khóa theo trong ZIP (`tunnel_key`) nay tự copy
  vào `data/` ngay trước khi mở tunnel (lần đầu), kể cả convert sang định dạng
  dropbear khi cần.

## v0.5.1

- Sửa `remote-ui` không chạy (`GLIBC_2.34 not found` — build lại trên Ubuntu 18.04,
  tương thích glibc từ 2.27).
- Sửa `remote.sh start` báo thất bại giả: CPU máy yếu + lần đầu sinh host-key nên
  quá 1 giây — nay chờ pidfile tới ~8 giây (log thật đã cho thấy dropbear vẫn chạy).
- `show-status` hiện đúng chữ VPS/Pinggy theo chế độ tunnel đang dùng.

## v0.5.0

- **OTA tự động (repo đã public)**: mở app là kiểm tra + lên bản mới foreground
  (tối đa 60s), xong **tự khởi động lại app** chạy code mới ngay — đúng 1 lần mở.
  Tắt bằng `REMOTE_NO_OTA=1`.
- **Màn hình hướng dẫn riêng (chữ TO, có dấu)**: không dùng chung Terminal nữa
  (chữ nhỏ khó đọc) mà dùng binary `remote-ui` vẽ bằng pixel thật: cách SSH LAN,
  cách SSH Internet, user/pass. Thoát bằng **B 2 lần**, có **panel xác nhận to
  giữa màn hình**; thoát màn hình không tắt dịch vụ nền.

## v0.4.0

- **Bỏ màn hình terminal khỏi app (chạy ẩn hoàn toàn)**: đúng mục đích “PC remote vào
  đọc log, không gõ gì trên máy” nên không cần bàn phím ảo, không cần đọc chữ nhỏ.
  Mở app là bật dịch vụ + thoát ngay; endpoint VPS là **cố định** nên dev không cần
  nhìn màn hình máy.
- Sửa lỗi `ssh trimui-brick` báo “No such host”: do block Host chưa được chép vào
  `.ssh/config` trên PC (đã chép sẵn, file `pc-ssh-config.txt` chỉ còn để tham khảo).
- `STATUS.txt` vẫn ghi ra cạnh app để đọc qua thẻ nhớ khi cần debug.

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
