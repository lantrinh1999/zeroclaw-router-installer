---
name: openwrt-status-report
description: Báo cáo tổng hợp trạng thái router OpenWrt
version: 1.0.0
---

# OpenWrt Status Report

Tạo báo cáo tổng hợp trạng thái router.

## Lệnh
```bash
echo "=== BOARD ===" && ubus call system board
echo "=== UPTIME ===" && uptime
echo "=== MEMORY ===" && free -m
echo "=== DISK ===" && df -h
echo "=== SERVICES ===" && for s in zeroclaw cliproxyapi nginx dnsmasq; do printf "%-15s: " "$s"; /etc/init.d/$s status || echo "not found"; done
echo "=== NETWORK ===" && ip -brief addr show
echo "=== WIFI ===" && iwinfo | grep -E "ESSID|Channel|Signal"
echo "=== CLIENTS ===" && cat /tmp/dhcp.leases | wc -l
```

Format báo cáo rõ ràng, tiếng Việt.
