---
name: openwrt-package-manager
description: Quản lý package OpenWrt - cài, gỡ, update bằng opkg
version: 1.0.0
---

# OpenWrt Package Manager

Quản lý packages trên router OpenWrt bằng opkg.

## Lệnh
```bash
opkg update                        # Update danh sách
opkg list | grep "$KEYWORD"        # Tìm package
opkg list-installed                # Xem đã cài
opkg install $PACKAGE              # Cài
opkg remove $PACKAGE               # Gỡ
opkg info $PACKAGE                 # Xem info
opkg files $PACKAGE                # Xem file của package
df -h /overlay                     # Kiểm tra disk trước khi cài
opkg list-installed | wc -l        # Đếm packages
```

## Lưu ý
- Overlay storage rất hạn chế (~100MB), kiểm tra `df -h /overlay` trước khi cài
- Một số package cần kernel module tương thích
- Sau firmware upgrade phải cài lại packages

Tiếng Việt.
