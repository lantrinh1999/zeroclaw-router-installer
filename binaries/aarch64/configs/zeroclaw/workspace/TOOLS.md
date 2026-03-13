# TOOLS.md — Router Environment Notes

## Router Info

- **Model:**
- **OS:**
- **Shell:**
- **Package manager:**
- **Init system:**
- **Logs:**

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

## Skills (Local)

- `skills/openwrt-service-health` — kiểm tra health dịch vụ (zeroclaw/cliproxyapi/nginx/dnsmasq/AdGuard)
- `skills/openwrt-healthcheck` — kiểm tra nhanh sức khỏe hệ thống
- `skills/openwrt-wifi-survey` — khảo sát nhiễu kênh, RSSI, client Wi‑Fi
- `skills/openwrt-network-diagnosis` — chẩn đoán WAN/DNS/route/MTU/IPv6
- `skills/openwrt-config-backup-restore` — backup/restore UCI cấu hình
- `skills/openwrt-status-report` — báo cáo trạng thái router (1 lệnh)
- `skills/lynx-browser` — đọc web bằng Lynx (router-friendly)

## Policy Constraints (Observed)

Các case **bị policy chặn** khi chạy lệnh shell:

- `>` (redirection)
- `>>` (append)
- `2>` (stderr redirection)
- `$(...)` (command substitution)

**OK:** `|`, `&&`, `||`, `(...)`.

### Thay thế an toàn

- Không dùng redirection; in output trực tiếp ra console.
- Nếu cần giới hạn log, dùng `logread -e <tag> -l <n>`.
- Với `$(...)`, chạy lệnh riêng rồi dùng kết quả thủ công.
