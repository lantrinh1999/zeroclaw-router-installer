#!/bin/sh
# =======================================================
# ZeroClaw + CLIProxyAPI Uninstaller for procd-based systems
# =======================================================
# Supports: OpenWrt, kWrt, ImmortalWrt, and any procd-based firmware
# Usage: sh uninstall.sh (run on router)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
. "$ROOT_DIR/common.sh"

detect_platform
PLATFORM="procd"

echo ""
echo "======================================================="
printf "${RED} ZeroClaw + CLIProxyAPI Uninstaller (procd)${NC}\n"
echo "======================================================="
echo ""

# -- Backup? -----------------------------------------
if confirm "Bạn có muốn backup config/memory trước khi gỡ?"; then
    backup_configs
fi

# -- Stop services -----------------------------------
stop_existing_services

# -- Disable auto-start ------------------------------
info "Disabling auto-start..."
/etc/init.d/zeroclaw disable 2>/dev/null || true
/etc/init.d/cliproxyapi disable 2>/dev/null || true
info "  Auto-start disabled"

# -- Remove binaries ---------------------------------
info "Removing binaries..."
rm -f /usr/bin/zeroclaw
info "  /usr/bin/zeroclaw"

# -- Remove CLIProxyAPI ------------------------------
info "Removing CLIProxyAPI..."
rm -rf /opt/cliproxyapi
info "  /opt/cliproxyapi/"

# -- Remove ZeroClaw config --------------------------
info "Removing ZeroClaw config..."
rm -rf /root/.zeroclaw
info "  /root/.zeroclaw/"

# -- Remove init scripts ----------------------------
info "Removing init scripts..."
rm -f /etc/init.d/zeroclaw
rm -f /etc/init.d/cliproxyapi
info "  /etc/init.d/zeroclaw"
info "  /etc/init.d/cliproxyapi"

# -- Remove firewall rules --------------------------
info "Removing firewall rules..."
REMOVED=0
while uci show firewall 2>/dev/null | grep -q "Allow-CLIProxy"; do
    IDX=$(uci show firewall 2>/dev/null | grep "Allow-CLIProxy" | head -1 | sed "s/.*\[\([0-9]*\)\].*/\1/")
    uci delete "firewall.@rule[$IDX]" 2>/dev/null
    REMOVED=$((REMOVED + 1))
done
if [ "$REMOVED" -gt 0 ]; then
    uci commit firewall 2>/dev/null
    /etc/init.d/firewall restart 2>/dev/null
    info "  $REMOVED firewall rule(s) removed"
else
    info "  No firewall rules to remove"
fi

# -- Remove socat ------------------------------------
if opkg list-installed 2>/dev/null | grep -q "^socat "; then
    if confirm_strict "Gỡ package socat?"; then
        opkg remove socat 2>/dev/null
        info "  socat removed"
    else
        info "  socat kept"
    fi
fi

# -- Clean temp --------------------------------------
info "Cleaning temp files..."
rm -rf /tmp/zeroclaw-router-installer
info "  /tmp/zeroclaw-router-installer/"

# -- Summary -----------------------------------------
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
    echo "  Để khôi phục sau khi cài lại:"
    echo "    cp $BACKUP_DIR/config.toml /root/.zeroclaw/"
    echo "    cp $BACKUP_DIR/auth/*.json /opt/cliproxyapi/auth/"
fi

echo ""
