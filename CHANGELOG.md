# Changelog — Trimui-Remote

## v0.8.4

- **Binary `remote-ui` mới (CI build từ source v0.8.2)**: nút **Y** tắt đèn màn
  hình kiểu Music Player + bấm phím bất kỳ để sáng lại, lúc tắt nghỉ 100ms
  nên mát CPU. Các bản 0.8.2/0.8.3 mới chỉ có source + `screen.sh` (dùng qua
  SSH), bản này OTA cả binary nên bấm Y trên máy thật mới đen màn.

## v0.8.3

- **Sửa loop v0.8.2 không chạy được trên máy**: shell trên máy (hush) báo
  `line 16: syntax error: unexpected "("` với số học lồng nhau
  `tail -c +$(($MSZ + 1))`. Viết lại loop chỉ bằng cú pháp tối giản
  (`grep -c` + so chuỗi + `case`), backoff `15s->55s`. Tăng version để máy
  tự hủy loop v0.8.2 hỏng khi `tunnel.sh start` lại.

## v0.8.2

- **Tắt đèn màn hình kiểu Music Player (nút Y)**: `ioctl(/dev/disp, 0x102, 0)`
  để màn đen nhưng máy vẫn thức + WiFi sống (khác Power=suspend=tắt WiFi).
  Bấm phím bất kỳ để sáng lại. Lúc tắt UI nghỉ 100ms/frame nên mát CPU.
  Dùng ngay qua SSH khi đã B-thoát: `sh screen.sh off` / `sh screen.sh on`.
- **Giữ `/tmp/stay_alive` khi SSH nền còn sống**: `launch.sh` tạo lúc mở,
  B-thoát giữ lại, chỉ xóa khi X-tắt dịch vụ (đo thực tế: mất file này là
  auto-suspend giết dropbear/tunnel). Crash để màn đen thì lần mở sau tự
  sáng lại qua `data/display-restore.json`.
- **Diệt tunnel zombie**: `dbclient` không có `ExitOnForwardFailure` như `ssh`
  nên forward fail (trùng `VPS_RPORT` trên VPS) vẫn giữ kết nối chết gây nóng.
  Loop nay kill sau 12s nếu thấy `Remote TCP forward request failed`, backoff
  `5s->55s` khi rớt liên tục thay vì 5s cố định.

## v0.8.1

- **Không ship private key trong ZIP public**: `tunnel_key` loại khỏi đóng gói
  (kèm `tunnel.conf` đã loại ở bản dọn public). Nạp key bằng tay một lần qua
  `scp` vào `data/` (sống sót qua OTA). Kèm xoay key mới trên VPS sau khi phát
  hiện key cũ lọt vào asset release v0.8.0.

## v0.8.0

- **Chữ có dấu đầy đủ** trên màn hình app và file `STATUS.txt` (font DejaVu đã có
  sẵn chữ Việt; dòng gợi ý tách 2 hàng cho vừa màn hình).
- **Intro logo NLK 2.2 giây** khi mở app, giống hệt Music-Player / chiaki-ng /
  Terminal (bay lên lần lượt, đổi đỏ, tia sáng quét; bấm phím bất kỳ để bỏ qua;
  tắt bằng `REMOTE_NO_INTRO=1`, file `intro.off`/`.no-intro` hoặc
  `"intro": false` trong `config.json`).

## v0.7.0

- Thêm nút **X: tắt dịch vụ + thoát** (tiết kiệm pin): bấm X 2 lần, panel xác nhận
  to giữa màn hình, app tắt cả SSH LAN lẫn tunnel rồi mới thoát. Mở app lúc cần
  là dịch vụ chạy lại.
- B (2 lần) giữ nguyên: chỉ thoát màn hình, dịch vụ vẫn chạy nền.

## v0.6.1

- Sửa lỗi `.../bin/-p: not found` (thấy trên ảnh chụp log): dựng lệnh tunnel bằng
  cách thay thế chuỗi đã làm mất tên binary `dbclient`. Nay truyền đường dẫn
  binary đầy đủ (`$APP/bin/dbclient`) thẳng vào lệnh từ đầu.

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
