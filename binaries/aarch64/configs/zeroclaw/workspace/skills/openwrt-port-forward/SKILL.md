---
name: openwrt-port-forward
description: Quản lý port forwarding nhanh trên OpenWrt
version: 1.0.0
---

# Port Forwarding

Quản lý port forwarding (NAT) trên router OpenWrt.

## Xem port forwards hiện tại
```bash
echo "=== UCI Port Forwards ==="
uci show firewall | grep redirect -A8
echo "=== NAT Rules ==="
iptables -t nat -L PREROUTING -n --line-numbers
echo "=== Listening Ports ==="
netstat -tlnp
```

## Thêm port forward
```bash
uci add firewall redirect
uci set firewall.@redirect[-1].name="$NAME"
uci set firewall.@redirect[-1].src="wan"
uci set firewall.@redirect[-1].src_dport="$EXT_PORT"
uci set firewall.@redirect[-1].dest="lan"
uci set firewall.@redirect[-1].dest_ip="$LAN_IP"
uci set firewall.@redirect[-1].dest_port="$INT_PORT"
uci set firewall.@redirect[-1].proto="tcp udp"
uci set firewall.@redirect[-1].target="DNAT"
uci commit firewall
/etc/init.d/firewall restart
```

## Xoá port forward
```bash
# Tìm index
uci show firewall | grep "redirect.*name"
# Xoá theo index (thay N)
uci delete firewall.@redirect[N]
uci commit firewall
/etc/init.d/firewall restart
```

Tiếng Việt. Xác nhận trước khi thêm/xoá.
