---
name: openwrt-firewall
description: Quản lý firewall OpenWrt - rules, zones, port forwarding, traffic rules
version: 1.0.0
---

# OpenWrt Firewall Management

Xem và quản lý firewall trên router OpenWrt.

## Xem rules
```bash
echo "=== ZONES ===" && uci show firewall | grep "=zone"
echo "=== FORWARDING ===" && uci show firewall | grep "=forwarding"
echo "=== RULES ===" && uci show firewall | grep "=rule" -A5
echo "=== PORT FORWARDS ===" && uci show firewall | grep "=redirect" -A8
echo "=== IPTABLES ===" && iptables -L -n --line-numbers | head -50
echo "=== NAT ===" && iptables -t nat -L -n --line-numbers | head -30
```

## Thêm rule chặn IP
```bash
uci add firewall rule
uci set firewall.@rule[-1].name="Block_$IP"
uci set firewall.@rule[-1].src="wan"
uci set firewall.@rule[-1].src_ip="$IP"
uci set firewall.@rule[-1].target="DROP"
uci commit firewall
/etc/init.d/firewall restart
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

Tiếng Việt. Luôn xác nhận trước khi thay đổi firewall.
