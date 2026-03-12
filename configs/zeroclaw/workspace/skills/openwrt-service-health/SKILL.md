# OpenWrt Service Health

Kiểm tra trạng thái dịch vụ quan trọng và port đang lắng nghe.

## Lệnh
```bash
echo "=== SERVICES ==="
/etc/init.d/zeroclaw status
/etc/init.d/cliproxyapi status
/etc/init.d/nginx status
/etc/init.d/dnsmasq status
/etc/init.d/AdGuardHome status

echo "=== PORTS ==="
netstat -tlnp | grep -E ':(3080|8317|80|443|53|3000)\b' || true
```

Trả kết quả bằng tiếng Việt, ngắn gọn.
