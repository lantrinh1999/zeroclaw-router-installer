# TOOLS.md — Router Environment Notes

## Router Info

- **Model:** GL-iNet MT7986 (aarch64, 4 cores, 1GB RAM)
- **OS:** OpenWrt with GL-iNet firmware
- **Shell:** /bin/ash (BusyBox, NOT bash)
- **Package manager:** opkg
- **Init system:** procd
- **Logs:** logread (không có journalctl)

## Useful Commands (Expanded)

- `top -b -n1` — CPU/RAM usage
- `free -m` — memory
- `df -h` — disk usage
- `logread | tail -50` — system logs
- `dmesg | tail -50` — kernel logs
- `uci show` — OpenWrt config
- `uci export` — snapshot cấu hình UCI
- `opkg list-installed` — installed packages
- `/etc/init.d/<service> start|stop|restart|status`
- `ubus call system board` — hardware info
- `ubus call network.interface.wan status` — WAN status
- `ifstatus wan` — WAN status (legacy)
- `ip a` / `ip r` — interfaces & routes
- `iwinfo` — WiFi info
- `iw dev` — wireless devices
- `iwinfo <radio> assoclist` — danh sách client Wi‑Fi
- `cat /proc/net/dev` — network stats
- `nslookup <domain> 127.0.0.1` — test DNS local
- `ping -c 3 1.1.1.1` / `ping -c 3 8.8.8.8`
- `traceroute -n <ip>` — route path
- `netstat -lnpt` hoặc `ss -lnpt` — ports (tùy có)

## Network Services trên Router

- **AdGuard Home:** port 3000 (DNS filtering)
- **Cliproxy API:** port 8317 (LLM proxy)
- **Router Agent Gateway:** port 3080 (web UI)
- **Nginx (GL-iNet):** port 80/443

## Skills (Local)

- `skills/openwrt-service-health` — kiểm tra health dịch vụ (zeroclaw/cliproxyapi/nginx/dnsmasq/AdGuard)
- `skills/openwrt-healthcheck` — kiểm tra nhanh sức khỏe hệ thống
- `skills/openwrt-wifi-survey` — khảo sát nhiễu kênh, RSSI, client Wi‑Fi
- `skills/openwrt-network-diagnosis` — chẩn đoán WAN/DNS/route/MTU/IPv6
- `skills/openwrt-config-backup-restore` — backup/restore UCI cấu hình
- `skills/openwrt-status-report` — báo cáo trạng thái router (1 lệnh)
- `skills/lynx-browser` — đọc web bằng Lynx (router-friendly)

## Caveats

- Không có bash, dùng ash — syntax khác (không có `[[ ]]`, dùng `[ ]`)
- Không có systemctl, dùng /etc/init.d/\*
- BusyBox utilities — flags có thể khác GNU coreutils
- `curl` có sẵn nhưng là bản minimal
- Không có `python3`, `node`, `docker`
