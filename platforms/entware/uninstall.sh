#!/bin/sh
# =======================================================
# ZeroClaw + CLIProxyAPI Uninstaller for Entware/Buildroot
# =======================================================
# Usage: sh uninstall.sh (run on device)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
. "$ROOT_DIR/common.sh"

detect_platform
PLATFORM="entware"

echo ""
echo "======================================================="
printf "${RED} ZeroClaw + CLIProxyAPI Uninstaller (Entware)${NC}\n"
echo "======================================================="
echo ""

# -- Backup? -----------------------------------------
if confirm "Bạn có muốn backup config/memory trước khi gỡ?"; then
    backup_configs
fi

# -- Stop services -----------------------------------
stop_existing_services

# -- Remove init scripts ----------------------------
info "Removing init scripts..."
rm -f /opt/etc/init.d/S99zeroclaw
rm -f /opt/etc/init.d/S98cliproxyapi
info "  /opt/etc/init.d/S99zeroclaw"
info "  /opt/etc/init.d/S98cliproxyapi"

# -- Remove binaries ---------------------------------
info "Removing binaries..."
rm -f /opt/bin/zeroclaw
info "  /opt/bin/zeroclaw"

# -- Remove CLIProxyAPI ------------------------------
info "Removing CLIProxyAPI..."
rm -rf /opt/cliproxyapi
info "  /opt/cliproxyapi/"

# -- Remove ZeroClaw config --------------------------
info "Removing ZeroClaw config..."
rm -rf /root/.zeroclaw
info "  /root/.zeroclaw/"

# -- Remove logs & PID files ------------------------
info "Removing logs and PID files..."
rm -f /opt/var/run/zeroclaw.pid
rm -f /opt/var/run/cliproxyapi.pid
rm -f /opt/var/run/socat_bridge.pid
rm -f /opt/var/log/zeroclaw.log
rm -f /opt/var/log/cliproxyapi.log
info "  PID files and logs removed"

# -- Remove socat (optional) ------------------------
if [ -x /opt/bin/opkg ] && /opt/bin/opkg list-installed 2>/dev/null | grep -q "^socat "; then
    if confirm_strict "Gỡ package socat (Entware)?"; then
        /opt/bin/opkg remove socat 2>/dev/null
        info "  socat removed"
    else
        info "  socat kept"
    fi
fi

# -- Clean PATH from profile ------------------------
if [ -f /opt/etc/profile ]; then
    sed -i '/# ZeroClaw PATH/d' /opt/etc/profile 2>/dev/null || true
    sed -i '/zeroclaw/d' /opt/etc/profile 2>/dev/null || true
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

REMAINING=$(ps w 2>/dev/null | grep -c "[z]eroclaw\|[c]li-proxy-api" || echo "0")
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
