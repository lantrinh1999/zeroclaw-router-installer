---
name: openwrt-speedtest
description: Test tốc độ mạng WAN bằng curl trên router
version: 1.0.0
---

# Speed Test

Test tốc độ internet trên router bằng curl (không cần speedtest-cli).

## Download test
```bash
echo "=== Download Speed Test ==="
curl -o /dev/null -w "Speed: %{speed_download} bytes/s\nTime: %{time_total}s\n" -s "http://speedtest.tele2.net/10MB.zip"
```

## Quick test (1MB)
```bash
curl -o /dev/null -w "Download: %{speed_download} bytes/s (%{time_total}s)\n" -s "http://speedtest.tele2.net/1MB.zip"
```

## Latency test
```bash
echo "=== Latency ==="
ping -c5 8.8.8.8 | tail -1
ping -c5 1.1.1.1 | tail -1
```

## DNS resolution speed
```bash
time nslookup google.com > /dev/null 2>&1
```

Tiếng Việt.
