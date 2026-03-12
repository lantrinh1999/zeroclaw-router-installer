---
name: openwrt-wake-on-lan
description: Gửi Wake-on-LAN packet đánh thức thiết bị trong mạng LAN
version: 1.0.0
---

# Wake-on-LAN

Gửi magic packet để đánh thức thiết bị LAN từ router.

## Gửi WOL
```bash
# Dùng etherwake (thường có sẵn trên OpenWrt)
etherwake -i br-lan $MAC_ADDRESS

# Nếu chưa có etherwake
opkg update && opkg install etherwake
```

## Tìm MAC address thiết bị
```bash
cat /tmp/dhcp.leases
ip neigh show | grep -v FAILED
```

## Kiểm tra thiết bị đã thức chưa
```bash
ping -c3 -W2 $IP_ADDRESS
```

## Lưu ý
- Thiết bị phải hỗ trợ WOL và bật trong BIOS/OS
- Chủ yếu hoạt động qua Ethernet (có dây)
- Một số thiết bị hỗ trợ WOL qua WiFi nhưng hiếm

Tiếng Việt.
