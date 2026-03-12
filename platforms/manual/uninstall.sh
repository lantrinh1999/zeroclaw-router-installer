#!/bin/sh
# =======================================================
# ZeroClaw + CLIProxyAPI Uninstaller (manual mode)
# =======================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

. "$ROOT_DIR/common.sh"

detect_platform
PLATFORM="manual"

echo ""
echo "======================================================="
printf "${RED} ZeroClaw + CLIProxyAPI Uninstaller (manual)${NC}\n"
echo "======================================================="
echo ""

if confirm "Bạn có muốn backup config/memory trước khi gỡ?"; then
    backup_configs
fi

stop_existing_services
cleanup_existing_installation

info "Removing ZeroClaw config..."
rm -rf /root/.zeroclaw
info "  /root/.zeroclaw/"

info "Removing CLIProxyAPI directories..."
rm -rf /opt/cliproxyapi
rm -rf /usr/local/lib/zeroclaw
rm -rf /usr/lib/zeroclaw
info "  /opt/cliproxyapi/"
info "  /usr/local/lib/zeroclaw/"
info "  /usr/lib/zeroclaw/"

info "Removing manual service scripts..."
rm -f /usr/local/bin/zeroclaw-service /usr/local/bin/cliproxyapi-service
rm -f /opt/bin/zeroclaw-service /opt/bin/cliproxyapi-service
rm -f /usr/bin/zeroclaw-service /usr/bin/cliproxyapi-service
info "  manual service scripts removed"

info "Removing manual logs and PID files..."
rm -f /var/log/zeroclaw.log /var/log/cliproxyapi.log
rm -f /opt/var/log/zeroclaw.log /opt/var/log/cliproxyapi.log
rm -f /tmp/zeroclaw.log /tmp/cliproxyapi.log
rm -f /var/run/zeroclaw.pid /var/run/cliproxyapi.pid /var/run/cliproxyapi-bridge.pid
rm -f /opt/var/run/zeroclaw.pid /opt/var/run/cliproxyapi.pid /opt/var/run/cliproxyapi-bridge.pid
rm -f /tmp/zeroclaw.pid /tmp/cliproxyapi.pid /tmp/cliproxyapi-bridge.pid
info "  manual logs and PID files removed"

info "Cleaning temp files..."
rm -rf /tmp/zeroclaw-router-installer
info "  /tmp/zeroclaw-router-installer/"

echo ""
echo "======================================================="
printf "${GREEN} Gỡ cài đặt hoàn tất!${NC}\n"
echo "======================================================="
echo ""

REMAINING=$(( $(process_count zeroclaw) + $(process_count cli-proxy-api) ))
if [ "$REMAINING" -gt 0 ]; then
    warn "Còn $REMAINING process đang chạy. Reboot nếu cần."
else
    info "Không còn process nào."
fi

if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
    echo ""
    info "Backup đã lưu tại: $BACKUP_DIR"
fi

echo ""
