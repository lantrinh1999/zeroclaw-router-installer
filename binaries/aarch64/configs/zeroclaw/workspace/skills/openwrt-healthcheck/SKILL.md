---
name: openwrt-healthcheck
description: Health check cho router OpenWrt - CPU, RAM, disk, temp, uptime
version: 1.0.0
---

# OpenWrt Health Check

Chạy health check toàn diện cho router.

## Lệnh
```bash
echo "=== UPTIME ===" && uptime
echo "=== MEMORY ===" && free -m
echo "=== DISK ===" && df -h /overlay
echo "=== LOAD ===" && cat /proc/loadavg
echo "=== TEMP ===" && cat /sys/class/thermal/thermal_zone0/temp || echo "N/A"
echo "=== TOP 5 PROCESS ===" && top -b -n1 | head -12
echo "=== SWAP ===" && cat /proc/swaps
```

Trả kết quả bằng tiếng Việt, format rõ ràng.
