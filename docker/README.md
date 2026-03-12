# Docker Test Environment (Multi-Device)

Giả lập nhiều mẫu router để test ZeroClaw installer. Mỗi thiết bị có `docker-compose.yml` riêng.

## Thiết bị

| ID | Model | OS | Compose |
|----|-------|----|---------|
| `jdc1800pro` | JDCloud RE-SS-01 | Kwrt 24.10.4 | `devices/jdc1800pro/docker-compose.yml` |

## Sử dụng

```bash
# Build
docker compose -f docker/devices/jdc1800pro/docker-compose.yml build

# Start
docker compose -f docker/devices/jdc1800pro/docker-compose.yml up -d

# Logs
docker logs jdc1800pro

# Test installer
sh setup.sh localhost -p 2222

# Stop
docker compose -f docker/devices/jdc1800pro/docker-compose.yml down
```

> Lỗi `REMOTE HOST IDENTIFICATION HAS CHANGED`:
> ```bash
> ssh-keygen -R "[localhost]:2222"
> ```

## Thêm thiết bị mới

1. Tạo `docker/devices/<tên>/` với 6 files:

```bash
# Lấy từ thiết bị thật
DEVICE=<tên>
IP=<ip>
mkdir -p docker/devices/$DEVICE
ssh root@$IP "cat /etc/kwrt_release"     > docker/devices/$DEVICE/kwrt_release
ssh root@$IP "cat /etc/openwrt_release"  > docker/devices/$DEVICE/openwrt_release
ssh root@$IP "cat /etc/os-release"       > docker/devices/$DEVICE/os-release
ssh root@$IP "ubus call system board"    > docker/devices/$DEVICE/ubus-board.json
ssh root@$IP "cat /etc/config/system"    > docker/devices/$DEVICE/config-system
```

2. Tạo `docker/devices/<tên>/docker-compose.yml`:

```yaml
services:
  <tên>:
    build:
      context: ../../
      dockerfile: Dockerfile
      args:
        DEVICE: <tên>
    container_name: <tên>
    hostname: <hostname>
    platform: linux/arm64
    cpus: <số cores>
    mem_limit: <ram>m
    memswap_limit: <ram>m
    tmpfs:
      - /overlay:size=<flash>m
    ports:
      - "2222:22"
      - "8317:8317"
      - "8318:8318"
      - "3080:3080"
    restart: unless-stopped
    stdin_open: true
    tty: true
```

3. Build & test:
```bash
docker compose -f docker/devices/<tên>/docker-compose.yml build
docker compose -f docker/devices/<tên>/docker-compose.yml up -d
sh setup.sh localhost -p 2222
```

## Cấu trúc

```
docker/
├── Dockerfile              # Shared (DEVICE build arg)
├── entrypoint.sh           # Shared (đọc device info tự động)
├── scripts/                # Shared fake tools
│   ├── fake-ubus.sh
│   ├── fake-opkg.sh
│   └── fake-logread.sh
├── devices/
│   └── jdc1800pro/         # Mỗi thiết bị 1 thư mục
│       ├── docker-compose.yml
│       ├── kwrt_release
│       ├── openwrt_release
│       ├── os-release
│       ├── ubus-board.json
│       └── config-system
└── README.md
```
