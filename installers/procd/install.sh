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

require_procd_init_scripts() {
    [ -f /etc/rc.common ] || {
        error "ONLY_BINARY requires existing /etc/rc.common"
        return 1
    }
    [ -x /etc/init.d/cliproxyapi ] || {
        error "ONLY_BINARY requires existing /etc/init.d/cliproxyapi"
        return 1
    }
    [ -x /etc/init.d/zeroclaw ] || {
        error "ONLY_BINARY requires existing /etc/init.d/zeroclaw"
        return 1
    }
}

stop_procd_services_for_only_binary() {
    require_procd_init_scripts || return 1

    step "Stopping services"
    /etc/init.d/cliproxyapi stop 2>/dev/null || true
    /etc/init.d/zeroclaw stop 2>/dev/null || true
    delete_procd_service_state
    force_release_service_runtime 10
}

start_procd_services() {
    require_procd_init_scripts || return 1
    MGMT_PORT=$(detect_management_port)

    step "Starting services"

    debug "Ensuring clean runtime state before service start..."
    prepare_fresh_service_start 10

    debug "Resetting procd service state before fresh start..."
    /etc/init.d/cliproxyapi stop 2>/dev/null || true
    /etc/init.d/zeroclaw stop 2>/dev/null || true
    delete_procd_service_state
    force_release_service_runtime 10

    MAX_CP_START_RETRIES=3
    CP_RETRY=1
    API_UP=0

    while [ "$CP_RETRY" -le "$MAX_CP_START_RETRIES" ]; do
        info "Starting CLIProxyAPI... (attempt ${CP_RETRY}/${MAX_CP_START_RETRIES})"
        debug "Running: /etc/init.d/cliproxyapi start"
        /etc/init.d/cliproxyapi start 2>&1 | while read line; do debug "  cliproxyapi: $line"; done

        wait_for_port_with_process_guard "$MGMT_PORT" cli-proxy-api 20 || true

        API_UP=$(is_port_listening "$MGMT_PORT" && echo "1" || echo "0")
        [ "$API_UP" = "1" ] && break

        warn "CLIProxyAPI (port $MGMT_PORT) did NOT start on attempt ${CP_RETRY}!"
        show_port_snapshot "$MGMT_PORT" 3080
        show_port_activity "$MGMT_PORT"
        PIDS=$(process_pids cli-proxy-api)
        [ -n "$PIDS" ] && debug "cli-proxy-api pid(s): $PIDS" || debug "cli-proxy-api pid(s): <none>"
        logread 2>/dev/null | grep -i 'cli-proxy' | tail -8 | while IFS= read -r line; do debug "logread: $line"; done

        if [ "$CP_RETRY" -lt "$MAX_CP_START_RETRIES" ]; then
            warn "Retrying CLIProxyAPI start after forced cleanup..."
            /etc/init.d/cliproxyapi stop 2>/dev/null || true
            delete_procd_service_state
            force_release_service_runtime 12
            sleep 2
        fi

        CP_RETRY=$((CP_RETRY + 1))
    done

    if [ "$API_UP" = "1" ]; then
        info "CLIProxyAPI is running on port $MGMT_PORT"
    else
        warn "CLIProxyAPI (port $MGMT_PORT) did NOT start!"
        show_port_snapshot "$MGMT_PORT" 3080
        show_port_activity "$MGMT_PORT"
        PIDS=$(process_pids cli-proxy-api)
        [ -n "$PIDS" ] && debug "cli-proxy-api pid(s): $PIDS" || debug "cli-proxy-api pid(s): <none>"
        logread 2>/dev/null | grep -i 'cli-proxy' | tail -5 | while IFS= read -r line; do debug "logread: $line"; done
        error "Check: logread | grep cli-proxy"
        return 1
    fi

    info "Starting ZeroClaw..."
    debug "Running: /etc/init.d/zeroclaw start"
    /etc/init.d/zeroclaw start 2>&1 | while read line; do debug "  zeroclaw: $line"; done
    sleep 3

    if is_process_running zeroclaw; then
        info "ZeroClaw is running "
    else
        warn "ZeroClaw may not have started. Check: logread | grep zeroclaw"
        PIDS=$(process_pids zeroclaw)
        [ -n "$PIDS" ] && debug "zeroclaw pid(s): $PIDS" || debug "zeroclaw pid(s): <none>"
    fi
}

enable_procd_autostart() {
    debug "Enabling auto-start..."
    /etc/init.d/cliproxyapi enable 2>/dev/null || warn "Failed to enable cliproxyapi"
    /etc/init.d/zeroclaw enable 2>/dev/null || warn "Failed to enable zeroclaw"
    info "Auto-start enabled for both services"
}

# -- Platform detection + confirm --------------------
step "Platform detection"
detect_platform
INSTALLER="procd"  # Force installer strategy for this installer

if [ "$BIN_ARCH" != "aarch64" ]; then
    error "This installer is for aarch64 procd-based systems only. Detected: $ARCH"
    error "For MIPS/Entware devices, use installers/entware/install.sh"
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

if [ "${ONLY_BINARY:-0}" = "1" ]; then
    info "ONLY_BINARY=1 detected; refreshing installed binaries and management UI only"
    run_only_binary_update "$BIN_SRC" "$CONFIGS" /usr/bin/zeroclaw /opt/cliproxyapi/cli-proxy-api /opt/cliproxyapi stop_procd_services_for_only_binary start_procd_services || exit 1
    step "Verification"
    verify_services
    exit 0
fi

# Ensure init script runtime exists on minimal/procd-like systems.
ensure_rc_common_compat || exit 1

# -- User input (safe for non-interactive) -----------
step "Telegram config (mandatory)"
ask_telegram_config || exit 1

# -- Cleanup existing installation (if reinstalling) --
cleanup_existing_installation

# -- Install binaries --------------------------------
step "Installing binaries"

debug "Installing zeroclaw to /usr/bin/zeroclaw (prefer mv)..."
if install_binary_from_stage "$BIN_SRC/zeroclaw" /usr/bin/zeroclaw "zeroclaw"; then
    chmod +x /usr/bin/zeroclaw
    info "  /usr/bin/zeroclaw installed ($(ls -la /usr/bin/zeroclaw | awk '{print $5}')B)"
else
    error "FATAL: Failed to install zeroclaw binary!"
    error "  Check disk space: $(df /usr 2>/dev/null | tail -1)"
    exit 1
fi

debug "Creating /opt/cliproxyapi/ ..."
mkdir -p /opt/cliproxyapi

debug "Installing cli-proxy-api to /opt/cliproxyapi/ (prefer mv)..."
if install_binary_from_stage "$BIN_SRC/cli-proxy-api" /opt/cliproxyapi/cli-proxy-api "cli-proxy-api"; then
    chmod +x /opt/cliproxyapi/cli-proxy-api
    info "  /opt/cliproxyapi/cli-proxy-api installed ($(ls -la /opt/cliproxyapi/cli-proxy-api | awk '{print $5}')B)"
else
    error "FATAL: Failed to install cli-proxy-api binary!"
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

set_zeroclaw_provider_port 8317 || exit 1

# -- Start services ----------------------------------
start_procd_services || exit 1

# -- Encrypt credentials ----------------------------
step "Encrypting credentials"
debug "Running: /usr/bin/zeroclaw config encrypt"
/usr/bin/zeroclaw config encrypt --config-dir /root/.zeroclaw 2>/dev/null || warn "Config encryption skipped"

# -- Enable auto-start (AFTER services confirmed working) --
enable_procd_autostart

# -- Summary -----------------------------------------
step "Verification"
verify_services

echo ""
info "Done! Send a message to your Telegram bot to test."
info "Debug log: cat $LOG_FILE"
