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
3. Lắp thẻ vào máy, mở **Trimui Remote** một lần:
   - Lần mở đầu = **bật** SSH nền, rồi tự thoát về menu.
   - Mở lần nữa = **tắt** SSH (toggle).
   - SSH nền **mất khi reboot/tắt máy** (mở app lại là có).

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

## Dùng SSH qua Internet bằng Pinggy (để test, không cần VPS)

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

## Dùng VPS sau này (khi bạn đã có VPS)

Sửa file `Apps/TrimuiRemote/data/tunnel.conf`:

```sh
MODE=vps
VPS_HOST=203.0.113.10
VPS_PORT=22
VPS_USER=root
VPS_RPORT=12222
```

Rồi chạy `sh tunnel.sh start`. Dev kết nối: `ssh -p 12222 root@203.0.113.10`
(thực chất là vào thẳng máy game). Port `12222` cố định, không đổi như Pinggy.

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

Xem `files/bin/README.txt`. Tóm tắt: cross-compile static aarch64 bằng SDK TG5050
(giống quy trình `Trimui-Terminal`), strip rồi chép vào `files/bin/`.
Khi chưa có binary, `remote.sh` tự fallback sang `dropbear` của hệ thống nếu có.

Đóng gói release (giống chuẩn Terminal):

```sh
python3 tools/make_release.py
python3 tools/verify_release.py
```
