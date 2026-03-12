---
name: openwrt-network-diagnosis
description: Chẩn đoán mạng - ping, DNS, routes, firewall, bandwidth
version: 1.0.0
---

# OpenWrt Network Diagnosis

Chẩn đoán kết nối mạng router.

## Lệnh
```bash
echo "=== WAN IP ===" && ip addr show | grep -A2 "wan"
echo "=== PING ===" && ping -c3 8.8.8.8
echo "=== DNS ===" && nslookup google.com
echo "=== ROUTES ===" && ip route show
echo "=== DHCP LEASES ===" && cat /tmp/dhcp.leases
echo "=== PORTS ===" && netstat -tlnp
echo "=== BANDWIDTH ===" && cat /proc/net/dev | grep -v lo
```

Phân tích kết quả, đề xuất fix nếu có vấn đề. Tiếng Việt.
