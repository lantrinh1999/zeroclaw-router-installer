# Docker Test Environment (Multi-Device)

Giả lập nhiều mẫu router để test ZeroClaw installer. Mỗi thiết bị có `docker-compose.yml` riêng.

## Thiết bị

| ID | Model | OS | Arch | Compose |
|----|-------|----|------|---------| 
| `jdc1800pro` | JDCloud RE-SS-01 | Kwrt 24.10.4 | aarch64 (arm64) | `devices/jdc1800pro/docker-compose.yml` |
| `crealityk1` | Creality K1 | Buildroot 2020.02 | mipsel (MIPS32r2) | `devices/crealityk1/docker-compose.yml` |

## Sử dụng

### jdc1800pro (ARM64 / OpenWrt)

```bash
docker compose -f docker/devices/jdc1800pro/docker-compose.yml build
docker compose -f docker/devices/jdc1800pro/docker-compose.yml up -d
sh setup.sh localhost -p 2222
docker compose -f docker/devices/jdc1800pro/docker-compose.yml down
```

Smoke test không tương tác cho detect + install + reboot auto-start:

```bash
sh docker/scripts/smoke-jdc1800pro-autostart.sh
```

Script này cần `sshpass` trên host và sẽ xác nhận:

- detector chọn `INSTALLER=procd`
- installer enable `/etc/rc.d/S98cliproxyapi` và `/etc/rc.d/S99zeroclaw`
- sau `docker restart jdc1800pro`, `cli-proxy-api` và `zeroclaw` tự chạy lại
- port `8317` nghe lại sau reboot giả lập

### crealityk1 (MIPS32r2 / Entware)

```bash
# Setup QEMU (chỉ chạy 1 lần)
docker run --privileged --rm tonistiigi/binfmt --install mipsel

# Build & start
docker compose -f docker/devices/crealityk1/docker-compose.yml build
docker compose -f docker/devices/crealityk1/docker-compose.yml up -d

# Test installer
sh setup.sh localhost -p 2223

# Stop
docker compose -f docker/devices/crealityk1/docker-compose.yml down
```

> Lỗi `REMOTE HOST IDENTIFICATION HAS CHANGED`:
> ```bash
> ssh-keygen -R "[localhost]:2222"
> ssh-keygen -R "[localhost]:2223"
> ```

## Thêm thiết bị mới

1. Tạo `docker/devices/<tên>/` với config files:

```bash
DEVICE=<tên>
IP=<ip>
mkdir -p docker/devices/$DEVICE
ssh root@$IP "cat /etc/os-release"       > docker/devices/$DEVICE/os-release
ssh root@$IP "ubus call system board"    > docker/devices/$DEVICE/ubus-board.json
ssh root@$IP "cat /etc/config/system"    > docker/devices/$DEVICE/config-system

# OpenWrt-based:
ssh root@$IP "cat /etc/kwrt_release"     > docker/devices/$DEVICE/kwrt_release
ssh root@$IP "cat /etc/openwrt_release"  > docker/devices/$DEVICE/openwrt_release

# Buildroot-based:
ssh root@$IP "cat /etc/buildroot-release" > docker/devices/$DEVICE/buildroot-release
```

2. Tạo `docker-compose.yml` (xem devices hiện có làm mẫu)
3. Chọn đúng Dockerfile:
   - ARM64 / OpenWrt: `Dockerfile`
   - MIPS32r2 / Buildroot: `Dockerfile.mips`

## Cấu trúc

```
docker/
├── Dockerfile              # ARM64 devices (Alpine-based)
├── Dockerfile.mips         # MIPS devices (Debian-based + QEMU)
├── entrypoint.sh           # ARM64/OpenWrt entrypoint
├── entrypoint-mips.sh      # MIPS/Buildroot entrypoint
├── scripts/                # Shared fake tools
│   ├── fake-ubus.sh
│   ├── fake-opkg.sh
│   ├── fake-logread.sh
│   ├── fake-entware-opkg.sh
│   └── smoke-jdc1800pro-autostart.sh
├── devices/
│   ├── jdc1800pro/         # ARM64 / Kwrt (OpenWrt)
│   │   ├── docker-compose.yml
│   │   ├── kwrt_release
│   │   ├── openwrt_release
│   │   ├── os-release
│   │   ├── ubus-board.json
│   │   └── config-system
│   └── crealityk1/         # MIPS32r2 / Buildroot + Entware
│       ├── docker-compose.yml
│       ├── buildroot-release
│       ├── os-release
│       ├── ubus-board.json
│       └── config-system
└── README.md
```

## Ghi chú boot giả lập

ARM64 OpenWrt/Kwrt container sẽ start fake `procd`, sau đó chạy các service đã được `enable` trong `/etc/rc.d/S*` theo đúng thứ tự symlink. Vì vậy `docker restart` có thể dùng như một bài test reboot để kiểm tra auto-start của installer `procd`.
