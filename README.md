# Trimui-Remote — SSH debug nhẹ cho TrimUI Brick Pro / Smart Pro S

App giúp người hỗ trợ **SSH từ xa vào máy để đọc log debug**, trong khi máy chỉ có **1GB RAM**.
Nguyên tắc: **nhẹ hết sức, chạy nền** — mở app là xong, không giữ giao diện nặng.

- **v0.1:** SSH trong mạng LAN (cùng WiFi) qua `dropbear`.
- **v0.2:** SSH qua Internet bằng **Pinggy** (reverse-SSH, không cần VPS).
- **Sau này:** VPS riêng (khi bạn cung cấp) + chế độ co-op retro 2 người.

Một bản duy nhất chạy cả **Brick Pro (1024×768)** và **Smart Pro S (1280×720)**.

## Vì sao nhẹ được?

| Thành phần | RAM | Ghi chú |
|---|---|---|
| `launch.sh`, `remote.sh`, `tunnel.sh` | ~0 (chạy xong là thoát) | shell POSIX, không Python/SDL |
| `dropbear` (SSH server) | ~1MB/kết nối | thay OpenSSH (~10MB+) |
| `tunnel` reverse-SSH | ~1MB | thay Tailscale (~30–50MB) |
| **Tổng chạy nền** | **<5MB / 1GB** | chơi game không bị ảnh hưởng |

## Cài đặt

1. Tải `trimui-remote-vX.Y.Z.zip` ở mục **Releases** của repo này.
2. Giải nén vào **gốc thẻ nhớ** để có `Apps/TrimuiRemote/launch.sh`.
3. Lắp thẻ vào máy, mở **Trimui Remote**:
   - App mở **ngay** (không chờ): tự bật SSH LAN + tunnel Internet rồi hiện
     **màn hình hướng dẫn chữ to**: cách SSH LAN, cách SSH Internet,
     user `root` + mật khẩu. Bản mới (nếu có) tự tải nền, lần mở sau dùng.
   - Thoát màn hình: **phím B 2 lần** (có panel xác nhận to giữa màn hình).
     Thoát màn hình **không tắt** dịch vụ nền.
   - Tắt hẳn dịch vụ (tiết kiệm pin): **phím X 2 lần** trên màn hình app
     (có panel xác nhận riêng). Lần sau mở app, dịch vụ chạy lại.
   - Muốn tắt hẳn: trong Trimui Terminal gõ `sh remote.sh stop` và `sh tunnel.sh stop`
     trong thư mục app.

## Dùng SSH trong mạng LAN (cùng WiFi)

Trên máy đã bật app, trên PC cùng WiFi:

```sh
ssh root@<IP-MAY> -p 2222
```

- `<IP-MAY>`: xem trong file `Apps/TrimuiRemote/Remote-ip.txt` trên thẻ nhớ.
- Mật khẩu: mật khẩu root của máy.
- Copy log về: `scp -P 2222 root@<IP-MAY>:/mnt/SDCARD/Logs/ ./`

Lệnh nhanh trên máy (trong Trimui Terminal):

```sh
sh /mnt/SDCARD/Apps/TrimuiRemote/remote.sh status
sh /mnt/SDCARD/Apps/TrimuiRemote/remote.sh stop
```

## Dùng SSH qua Internet bằng VPS (chính)

Máy game tự mở reverse-tunnel về VPS jump-host của bạn (máy giữ một port riêng
`VPS_RPORT` trên VPS).
Điền VPS của bạn vào `data/tunnel.conf` trên máy (qua SSH/Terminal), hoặc vào
`files/tunnel.conf` cục bộ trước khi đóng gói (file này không commit, không ship
trong ZIP — máy mới dùng `tunnel.conf.example`, mặc định pinggy).

Trên máy (trong Trimui Terminal, sau khi đã bật app):

```sh
sh /mnt/SDCARD/Apps/TrimuiRemote/tunnel.sh status
```

Từ **bất kỳ PC nào** (cần truy cập được VPS jump-host), thêm đoạn trong
`pc-ssh-config.txt` vào `%USERPROFILE%\.ssh\config` rồi chạy:

```sh
ssh trimui-brick
```

- User: `root` — Pass: mật khẩu root của máy game.
- Không cần cùng mạng, chỉ cần máy game có Internet lúc mở app.

### Nạp key tunnel cho máy (một lần duy nhất)

ZIP public **không kèm private key**. Sau khi cài app, chép key vào máy
(qua thẻ nhớ hoặc `scp`), rồi mở app:

```sh
scp tunnel_key root@<IP-MAY>:/mnt/SDCARD/Apps/TrimuiRemote/data/tunnel_key
ssh root@<IP-MAY> -p 2222 "chmod 600 /mnt/SDCARD/Apps/TrimuiRemote/data/tunnel_key"
```

Key nằm trong `data/` nên sống sót qua OTA. Mất key thì tunnel không nối được
(xem `tunnel.sh log` trên máy).

## Dùng Pinggy khi chưa muốn qua VPS (dự phòng)

Máy game và PC hỗ trợ **không cần cùng mạng**, chỉ cần cả hai đều có Internet.

Trên máy (trong Trimui Terminal, sau khi đã bật app):

```sh
sh /mnt/SDCARD/Apps/TrimuiRemote/tunnel.sh start
sh /mnt/SDCARD/Apps/TrimuiRemote/tunnel.sh log
```

Dòng log sẽ hiện địa chỉ công cộng do Pinggy cấp, ví dụ:

```
tcp://abc123xyz.a.pinggy.io:40567
```

Trên PC ở xa, kết nối vào địa chỉ đó:

```sh
ssh root@abc123xyz.a.pinggy.io -p 40567
```

Lưu ý của bản test:

- Mỗi lần `tunnel.sh start` lại, Pinggy cấp **port mới** → phải xem lại bằng `tunnel.sh log`.
- Bản free của Pinggy **giới hạn thời gian session** → tunnel có thể tự ngắt; script đã tự
  reconnect, nhưng port công cộng sẽ đổi.
- Lưu lượng đi qua máy chủ thứ ba → chỉ dùng để **đọc log test**, không dùng lâu dài.
- Tắt tunnel: `sh /mnt/SDCARD/Apps/TrimuiRemote/tunnel.sh stop`.

Chi tiết kỹ thuật: xem `docs/TUNNEL_PINGGY.md`.

## Dùng Pinggy khi chưa muốn qua VPS (dự phòng)

Đổi `MODE=pinggy` trong `data/tunnel.conf` rồi `sh tunnel.sh restart`. Còn lại
giữ nguyên các bước như mục Pinggy cũ dưới đây.

## Dùng SSH qua Internet bằng Pinggy (test nhanh, không cần VPS)

## Thu log debug (1 lệnh duy nhất)

Trên máy:

```sh
sh /mnt/SDCARD/Apps/TrimuiRemote/collect-logs.sh
```

File `Apps/TrimuiRemote/data/debug-YYYYMMDD-HHMMSS.tgz` chứa log hệ thống + trạng thái SSH.
Từ xa copy về:

```sh
scp -P 2222 root@<IP>:/mnt/SDCARD/Apps/TrimuiRemote/data/debug-*.tgz ./
```

## Cấu trúc app trên thẻ nhớ

```
Apps/TrimuiRemote/
  launch.sh  remote.sh  tunnel.sh  net-survey.sh  collect-logs.sh  ota-update.sh
  tunnel.conf.example  config.json  icon.png  VERSION  Remote-ip.txt
  bin/dropbear  bin/dropbearkey
  data/  (host-key, authorized_keys, tunnel.conf, pid, log, debug-*.tgz — giữ lại khi OTA)
```

## Bảo mật tối thiểu

- Host-key sinh **1 lần duy nhất** trong `data/`, không sinh lại mỗi lần boot.
- Nên chép public-key của người hỗ trợ vào `data/authorized_keys` để login bằng key.
- Port mặc định **2222** (tránh port 22), không mở port router, LAN chỉ dùng nội bộ.
- Tunnel Pinggy chỉ bật khi cần debug, xong thì `tunnel.sh stop`.

## Xử lý sự cố

| Hiện tượng | Cách kiểm tra |
|---|---|
| Không SSH được LAN | `remote.sh status`, ping IP trong `Remote-ip.txt`, chắc chắn cùng WiFi |
| `thieu dropbear` | chạy `sh net-survey.sh`, gửi file `Net-survey-*.log` để build binary |
| Tunnel không lên | `tunnel.sh log` xem lỗi, thử lại sau (Pinggy free hay nghẽn) |
| Mất SSH sau reboot | bình thường — mở app lại một lần |

## Build `bin/dropbear` (dành cho dev)

Binary static aarch64 (`dropbear`, `dbclient`, `dropbearkey`) được build tự động bằng
GitHub Actions (`.github/workflows/dropbear.yml`, `zig cc -target aarch64-linux-musl`),
tải về bằng `python3 tools/fetch_dropbear.py` rồi mới đóng gói release.
Không cần build tay trừ khi đổi phiên bản dropbear.

Đóng gói release (giống chuẩn Terminal):

```sh
python3 tools/make_release.py
python3 tools/verify_release.py
```
