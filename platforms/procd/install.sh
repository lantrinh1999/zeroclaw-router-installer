#!/bin/sh
# =======================================================
# ZeroClaw + CLIProxyAPI Installer for procd-based systems
# =======================================================
# Supports: OpenWrt, kWrt, ImmortalWrt, and any procd-based firmware
# Usage: sh install.sh (run on router)
# Requires: procd init, aarch64, ~100MB free disk space
# Debug log: /tmp/zeroclaw-install.log

# NO set -e -- we handle errors explicitly with logging
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions (logging, detect, etc.)
. "$ROOT_DIR/common.sh"

header "ZeroClaw + CLIProxyAPI Installer (procd)"
info "Log file: $LOG_FILE"
debug "SCRIPT_DIR=$SCRIPT_DIR"
debug "ROOT_DIR=$ROOT_DIR"
debug "SKIP_CONFIRM=${SKIP_CONFIRM:-<not set>}"
debug "TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:+<set, length=${#TELEGRAM_BOT_TOKEN}>}"
debug "TELEGRAM_USER_ID=${TELEGRAM_USER_ID:-<not set>}"
debug "stdin tty test: $([ -t 0 ] && echo 'interactive (tty)' || echo 'non-interactive (pipe/redirect)')"

# -- Platform detection + confirm --------------------
step "Platform detection"
detect_platform
PLATFORM="procd"  # Force platform for this installer

if [ "$BIN_ARCH" != "aarch64" ]; then
    error "This installer is for aarch64 procd-based systems only. Detected: $ARCH"
    error "For MIPS/Entware devices, use platforms/entware/install.sh"
    exit 1
fi

if [ "$OS_TYPE" != "openwrt" ]; then
    warn "Cannot detect procd-based system (OpenWrt/kWrt/ImmortalWrt)"
    warn "Detected OS: $OS_NAME ($OS_TYPE), Init: $INIT_TYPE"
    confirm "Continue anyway?" || exit 1
fi

confirm_platform || exit 1

# -- Pre-checks --------------------------------------
step "Pre-checks"
BIN_SRC="$ROOT_DIR/binaries/aarch64"
CONFIGS="$ROOT_DIR/configs"

check_disk_space 100 || exit 1
check_binaries_exist "$BIN_SRC" || exit 1

# -- User input (safe for non-interactive) -----------
step "Telegram config (mandatory)"
ask_telegram_config || exit 1

# -- Cleanup existing installation (if reinstalling) --
cleanup_existing_installation

# -- Install binaries --------------------------------
step "Installing binaries"

debug "Copying zeroclaw to /usr/bin/zeroclaw..."
if cp "$BIN_SRC/zeroclaw" /usr/bin/zeroclaw; then
    chmod +x /usr/bin/zeroclaw
    info "  /usr/bin/zeroclaw installed ($(ls -la /usr/bin/zeroclaw | awk '{print $5}')B)"
else
    error "FATAL: Failed to copy zeroclaw binary!"
    error "  Source: $BIN_SRC/zeroclaw"
    error "  Check disk space: $(df /usr 2>/dev/null | tail -1)"
    exit 1
fi

debug "Creating /opt/cliproxyapi/ ..."
mkdir -p /opt/cliproxyapi

debug "Copying cli-proxy-api to /opt/cliproxyapi/ ..."
if cp "$BIN_SRC/cli-proxy-api" /opt/cliproxyapi/cli-proxy-api; then
    chmod +x /opt/cliproxyapi/cli-proxy-api
    info "  /opt/cliproxyapi/cli-proxy-api installed ($(ls -la /opt/cliproxyapi/cli-proxy-api | awk '{print $5}')B)"
else
    error "FATAL: Failed to copy cli-proxy-api binary!"
    error "  Source: $BIN_SRC/cli-proxy-api"
    error "  Check disk space: $(df /opt 2>/dev/null | tail -1)"
    exit 1
fi

# -- Install configs ---------------------------------
install_zeroclaw_config "$CONFIGS"
install_cliproxy_config "$CONFIGS" "/opt/cliproxyapi"

# -- Install init scripts ----------------------------
step "Installing init scripts"

# Copy init scripts WITHOUT enabling (enable after start to prevent procd auto-launch)
debug "Copying cliproxyapi init script..."
if cp "$SCRIPT_DIR/init-scripts/cliproxyapi" /etc/init.d/cliproxyapi; then
    chmod +x /etc/init.d/cliproxyapi
    info "  /etc/init.d/cliproxyapi installed"
else
    error "FATAL: Failed to copy cliproxyapi init script!"
    exit 1
fi

debug "Copying zeroclaw init script..."
if cp "$SCRIPT_DIR/init-scripts/zeroclaw" /etc/init.d/zeroclaw; then
    chmod +x /etc/init.d/zeroclaw
    info "  /etc/init.d/zeroclaw installed"
else
    error "FATAL: Failed to copy zeroclaw init script!"
    exit 1
fi

# -- Inject Telegram config --------------------------
step "Telegram config injection"
inject_telegram_config

# -- Install socat -----------------------------------
step "Installing socat"
if command -v socat >/dev/null 2>&1; then
    info "socat already installed"
elif command -v opkg >/dev/null 2>&1; then
    info "Installing socat for IPv4 bridge..."
    debug "Running opkg update..."
    opkg update >/dev/null 2>&1 || warn "opkg update failed (repos unreachable? kWrt custom firmware?)"
    debug "Running opkg install socat..."
    opkg install socat 2>/dev/null || warn "socat install failed -- IPv4 access may not work"
else
    warn "opkg not found -- cannot install socat automatically"
    warn "Install socat manually for IPv4 bridge (port 8317)"
fi

# -- Start services ----------------------------------
step "Starting services"

# Safety: force kill anything on our ports right before start
debug "Pre-start port check..."
if netstat -tlnp 2>/dev/null | grep -qE ':831[78] |:3080 '; then
    warn "Ports still occupied before start, force killing..."
    debug "  Port state: $(netstat -tlnp 2>/dev/null | grep -E ':831[78] |:3080 ')"
    killall cli-proxy-api socat 2>/dev/null || true
    if command -v fuser >/dev/null 2>&1; then
        fuser -k 8318/tcp 2>/dev/null || true
        fuser -k 8317/tcp 2>/dev/null || true
    fi
    sleep 2
fi

# === START CLIProxyAPI ===
info "Starting CLIProxyAPI..."
debug "Running: /etc/init.d/cliproxyapi start"
/etc/init.d/cliproxyapi start 2>&1 | while read line; do debug "  cliproxyapi: $line"; done

# Wait for port 8318 (max 15s)
RETRIES=0
while [ $RETRIES -lt 15 ]; do
    if netstat -tlnp 2>/dev/null | grep -q ":8318 "; then
        debug "Port 8318 (api) detected after ${RETRIES}s"
        break
    fi
    if [ $RETRIES -gt 3 ] && ! ps w 2>/dev/null | grep -q '[c]li-proxy-api'; then
        debug "cli-proxy-api process died, no point waiting for port"
        break
    fi
    sleep 1
    RETRIES=$((RETRIES + 1))
done

# === VERIFY ===
API_UP=$(netstat -tlnp 2>/dev/null | grep -q ":8318 " && echo "1" || echo "0")
SOCAT_UP=$(netstat -tlnp 2>/dev/null | grep -q ":8317 " && echo "1" || echo "0")

if [ "$API_UP" = "1" ] && [ "$SOCAT_UP" = "1" ]; then
    info "CLIProxyAPI is running (socat:8317 -> api:8318)"
elif [ "$API_UP" = "1" ] && [ "$SOCAT_UP" = "0" ]; then
    debug "API up but socat not running, starting socat..."
    socat TCP4-LISTEN:8317,fork,reuseaddr TCP6:[::1]:8318 &
    sleep 1
    if netstat -tlnp 2>/dev/null | grep -q ":8317 "; then
        info "CLIProxyAPI is running (socat:8317 -> api:8318)"
    else
        warn "socat bridge failed to start"
    fi
else
    warn "CLIProxyAPI backend (port 8318) did NOT start!"
    debug "Logread: $(logread 2>/dev/null | grep -i 'cli-proxy' | tail -5)"
    error "Check: logread | grep cli-proxy"
fi

info "Starting ZeroClaw..."
debug "Running: /etc/init.d/zeroclaw start"
/etc/init.d/zeroclaw start 2>&1 | while read line; do debug "  zeroclaw: $line"; done
sleep 3

if ps w | grep -q "[z]eroclaw"; then
    info "ZeroClaw is running "
else
    warn "ZeroClaw may not have started. Check: logread | grep zeroclaw"
    debug "Processes: $(ps w | grep zeroclaw | grep -v grep)"
fi

# -- Encrypt credentials ----------------------------
step "Encrypting credentials"
debug "Running: /usr/bin/zeroclaw config encrypt"
/usr/bin/zeroclaw config encrypt --config-dir /root/.zeroclaw 2>/dev/null || warn "Config encryption skipped"

# -- Enable auto-start (AFTER services confirmed working) --
debug "Enabling auto-start..."
/etc/init.d/cliproxyapi enable 2>/dev/null || warn "Failed to enable cliproxyapi"
/etc/init.d/zeroclaw enable 2>/dev/null || warn "Failed to enable zeroclaw"
info "Auto-start enabled for both services"

# -- Summary -----------------------------------------
step "Verification"
verify_services

echo ""
info "Done! Send a message to your Telegram bot to test."
info "Debug log: cat $LOG_FILE"
