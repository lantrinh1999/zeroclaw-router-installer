---
name: openwrt-bandwidth-monitor
description: Theo dõi bandwidth theo interface và client trên router
version: 1.0.0
---

# Bandwidth Monitor

Theo dõi lưu lượng mạng trên router OpenWrt.

## Bandwidth theo interface
```bash
cat /proc/net/dev | grep -v lo | column -t
for iface in eth0 br-lan wan; do
  RX=$(cat /sys/class/net/$iface/statistics/rx_bytes || echo 0)
  TX=$(cat /sys/class/net/$iface/statistics/tx_bytes || echo 0)
  echo "$iface: RX=$((RX/1048576))MB TX=$((TX/1048576))MB"
done
```

## Realtime bandwidth (đo trong 2 giây)
```bash
IFACE="br-lan"
RX1=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
TX1=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)
sleep 2
RX2=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
TX2=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)
echo "Download: $(( (RX2-RX1)/2/1024 )) KB/s"
echo "Upload: $(( (TX2-TX1)/2/1024 )) KB/s"
```

## Top connections
```bash
echo "Active connections:"
cat /proc/net/nf_conntrack | wc -l
echo "=== Top talkers ==="
cat /proc/net/nf_conntrack | grep -oE "src=[0-9.]+" | sort | uniq -c | sort -rn | head -10
```

Tiếng Việt.
