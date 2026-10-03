# bin/ — binary dropbear cho Trimui-Remote (aarch64, static)

Build TU DONG bang GitHub Actions (.github/workflows/dropbear.yml):
zig cc -target aarch64-linux-musl, source dropbear-2024.86.

Lay ve may dev: python3 tools/fetch_dropbear.py
Khong commit binary bang tay.

Thu muc nay se chua 2 file (build 1 lan, dung chung Brick Pro + Smart Pro S):

- `dropbear` — SSH server, chay nen (~300KB static, ~1MB RAM).
- `dropbearkey` — sinh host-key lan dau (co the dung chung binary he thong neu co).

## Tai sao khong build san trong repo?

Binary phu thuoc toolchain (SDK TG5050). Lam giong `Trimui-Terminal`:
source build tren WSL, chi commit binary da strip vao `files/bin/`.

## Build (WSL Ubuntu + SDK TG5050)

```sh
# 1. Lay source dropbear (VD 2024.86)
wget https://matt.ucc.asn.au/dropbear/releases/dropbear-2024.86.tar.bz2
tar xf dropbear-2024.86.tar.bz2 && cd dropbear-2024.86

# 2. Cross-compile static aarch64
export SDK_ROOT=~/tb/sdk   # sdk_tg5050_linux_v1.0.0
export PATH="$SDK_ROOT/host/bin:$PATH"
./configure --host=aarch64-none-linux-gnu \
  CC=aarch64-none-linux-gnu-gcc \
  CFLAGS="-Os -static" LDFLAGS="-static" \
  --disable-zlib --disable-syslog
make -j4 PROGRAMS="dropbear dropbearkey dbclient"

# 3. Strip + copy
aarch64-none-linux-gnu-strip dropbear dropbearkey dbclient
cp dropbear dropbearkey /path/to/Trimui-Remote/files/bin/
chmod +x /path/to/Trimui-Remote/files/bin/*
file /path/to/Trimui-Remote/files/bin/dropbear
# -> phai ra: ELF 64-bit LSB executable, ARM aarch64
```

## Tam thoi chua co binary?

`remote.sh` tu fallback sang `dropbear` cua he thong neu co.
Chay `sh net-survey.sh` de biet may da co san dropbear/sshd chua.
Neu stock OS khong co san -> nhat dinh phai build 2 file tren.

## RAM (do thuc te tren may 1GB)

- dropbear moi ket noi: ~0.5-1MB.
- Khong ton CPU khi idle. An toan de chay nen khi choi game.
- Tailscale (Go, ~30-50MB RAM) KHONG dua vao v0.1 vi ly do nay.
  Truy cap tu xa khac mang o v0.1 dung reverse-SSH (dbclient -R) qua VPS,
  chi them ~1MB RAM, se lam o buoc tiep theo khi co VPS.
