# SSH qua Internet bằng Pinggy (tài liệu kỹ thuật)

## Ý tưởng

Máy game không có IP công cộng và nằm sau NAT nên dev ở xa không SSH trực tiếp được.
Thay vì thuê VPS, máy game **chủ động nối ra ngoài** (reverse-SSH) tới Pinggy,
Pinggy giữ một đầu công cộng và forward ngược về port 2222 (dropbear) trên máy:

```
máy game --(ssh -R0:localhost:2222)--> a.pinggy.io:443 --(tcp://xxx:port)--> dev ở xa
```

Tốn thêm ~1MB RAM, phù hợp máy 1GB.

## Lệnh chạy tay tương đương (để hiểu, không cần gõ)

```sh
ssh -p 443 -R0:localhost:2222 -N -T tcp@a.pinggy.io
```

- `-R0:...` = nhờ Pinggy cấp **port ngẫu nhiên** (hiện trong log dạng `tcp://...`).
- `-N -T` = chỉ giữ tunnel, không mở shell (nhẹ).
- Lưu ý: `-R 80:...` chỉ dùng cho demo HTTP của Pinggy, **SSH phải dùng TCP tunnel**
  như trên — `tunnel.sh` đã làm đúng.

## Luồng tự động trong `tunnel.sh`

1. Kiểm tra SSH LAN (`remote.sh`) đã chạy chưa — chưa thì bật trước.
2. Chọn client: `bin/dbclient` → `dbclient` hệ thống → `ssh` hệ thống.
3. Sinh `data/tunnel-loop.sh`: vòng lặp `while` chạy tunnel, rớt mạng thì chờ 5s thử lại.
4. Chạy nền bằng `setsid + nohup`, pid trong `data/tunnel.pid`, log trong `data/tunnel.log`.
5. `tunnel.sh status/log` đọc log, trích địa chỉ `tcp://host:port` để dev kết nối.

## Giới hạn của Pinggy free (chấp nhận khi test)

- Session **giới hạn thời gian**, ngắt rồi reconnect sẽ **đổi port mới**.
- Băng thông/tốc độ thấp hơn VPS, thỉnh thoảng nghẽn giờ cao điểm.
- Lưu lượng qua máy chủ thứ ba → chỉ đọc log test, không truyền dữ liệu nhạy cảm,
  không để tunnel mở thường trực.

## Chuyển sang VPS sau này

Đổi `data/tunnel.conf` sang `MODE=vps`, điền `VPS_HOST/VPS_USER/VPS_RPORT`,
chép key riêng vào `data/tunnel_key`, chạy `tunnel.sh restart`.
Lúc đó port công cộng **cố định** (`VPS_RPORT`), dev SSH: `ssh -p 12222 root@VPS`.
