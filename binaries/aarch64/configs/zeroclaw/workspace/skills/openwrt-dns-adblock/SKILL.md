---
name: openwrt-dns-adblock
description: Quản lý AdGuard Home - filter lists, stats, whitelist/blacklist
version: 1.0.0
---

# AdGuard Home Management

Quản lý AdGuard Home DNS filtering trên router (port 3000).

## API
```bash
# Status
curl -s http://127.0.0.1:3000/control/status

# Stats
curl -s http://127.0.0.1:3000/control/stats

# Query log (recent)
curl -s "http://127.0.0.1:3000/control/querylog?limit=20"

# Bật filtering
curl -s -X POST http://127.0.0.1:3000/control/dns_config -H "Content-Type: application/json" -d '{"protection_enabled":true}'

# Tắt filtering
curl -s -X POST http://127.0.0.1:3000/control/dns_config -H "Content-Type: application/json" -d '{"protection_enabled":false}'

# Xem filter lists
curl -s http://127.0.0.1:3000/control/filtering/status
```

## Config file
```bash
cat /opt/AdGuardHome/AdGuardHome.yaml
```

Tiếng Việt.
