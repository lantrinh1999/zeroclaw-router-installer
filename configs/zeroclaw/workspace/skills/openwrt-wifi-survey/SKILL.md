---
name: openwrt-wifi-survey
description: Khảo sát WiFi - SSID, clients, signal, channels
version: 1.0.0
---

# OpenWrt WiFi Survey

Khảo sát thông tin WiFi trên router.

## Lệnh
```bash
echo "=== WIFI INTERFACES ===" && iwinfo
echo "=== CONNECTED CLIENTS ===" && for iface in $(iwinfo | grep ESSID | awk '{print $1}'); do echo "-- $iface --"; iwinfo $iface assoclist; done
echo "=== WIFI CONFIG ===" && uci show wireless | grep -E "ssid|channel|band|disabled"
echo "=== NEARBY NETWORKS ===" && iwinfo $(iwinfo | head -1 | awk '{print $1}') scan | head -30
```

Trả kết quả bằng tiếng Việt.
