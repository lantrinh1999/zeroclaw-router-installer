---
name: openwrt-guest-wifi
description: Bật/tắt/cấu hình WiFi khách (Guest WiFi) trên OpenWrt
version: 1.0.0
---

# Guest WiFi Management

Quản lý mạng WiFi khách trên router OpenWrt.

## Xem WiFi hiện tại
```bash
uci show wireless | grep -E "ssid|disabled|encryption|key|network|device"
uci show wireless | grep -i guest
uci show network | grep -E "interface|ipaddr|proto" | grep -i guest
```

## Bật/tắt Guest WiFi
```bash
# Tìm guest interface index
uci show wireless | grep -i guest

# Bật (thay N bằng index)
uci set wireless.@wifi-iface[N].disabled=0
uci commit wireless
wifi reload

# Tắt
uci set wireless.@wifi-iface[N].disabled=1
uci commit wireless
wifi reload
```

## Đổi password Guest WiFi
```bash
uci set wireless.@wifi-iface[N].key="$NEW_PASSWORD"
uci commit wireless
wifi reload
```

## Xem client đang kết nối Guest
```bash
iwinfo | grep -B1 -i guest
iwinfo $GUEST_IFACE assoclist
```

Tiếng Việt.
