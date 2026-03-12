#!/bin/sh
# =======================================================
# ZeroClaw + CLIProxyAPI Installer (manual mode)
# =======================================================
# For: systems that can run the binaries but do not have a supported
# init/service backend in this repo yet.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

. "$ROOT_DIR/common.sh"

header "ZeroClaw + CLIProxyAPI Installer (manual)"

init_manual_runtime_paths() {
    MANUAL_SCRIPT_DIR="$INSTALL_BIN_DIR"
    MANUAL_PID_DIR=$(first_writable_path /var/run /opt/var/run /tmp)
    MANUAL_LOG_DIR=$(first_writable_path /var/log /opt/var/log /tmp)
    [ -n "$MANUAL_PID_DIR" ] || MANUAL_PID_DIR="/tmp"
    [ -n "$MANUAL_LOG_DIR" ] || MANUAL_LOG_DIR="/tmp"
}

require_manual_service_scripts() {
    init_manual_runtime_paths

    [ -x "$MANUAL_SCRIPT_DIR/cliproxyapi-service" ] || {
        error "ONLY_BINARY requires existing $MANUAL_SCRIPT_DIR/cliproxyapi-service"
        return 1
    }
    [ -x "$MANUAL_SCRIPT_DIR/zeroclaw-service" ] || {
        error "ONLY_BINARY requires existing $MANUAL_SCRIPT_DIR/zeroclaw-service"
        return 1
    }
}

stop_manual_services_for_only_binary() {
    require_manual_service_scripts || return 1

    step "Stopping services"
    "$MANUAL_SCRIPT_DIR/cliproxyapi-service" stop 2>/dev/null || true
    "$MANUAL_SCRIPT_DIR/zeroclaw-service" stop 2>/dev/null || true
    force_release_service_runtime 10
}

start_manual_services() {
    require_manual_service_scripts || return 1
    MGMT_PORT=$(detect_management_port)

    step "Starting services"
    prepare_fresh_service_start 10

    "$MANUAL_SCRIPT_DIR/cliproxyapi-service" start || return 1
    if wait_for_port_listening "$MGMT_PORT" 15; then
        info "CLIProxyAPI is running on port $MGMT_PORT"
    else
        warn "CLIProxyAPI may not have started. Check: $MANUAL_LOG_DIR/cliproxyapi.log"
        show_port_snapshot "$MGMT_PORT" 3080
    fi

    "$MANUAL_SCRIPT_DIR/zeroclaw-service" start || return 1
    sleep 3

    if is_process_running zeroclaw; then
        info "ZeroClaw is running"
    else
        warn "ZeroClaw may not have started. Check: $MANUAL_LOG_DIR/zeroclaw.log"
    fi
}

step "Platform detection"
detect_platform
INSTALLER="manual"
SERVICE_BACKEND="manual"
EXEC_MODE="manual-run"

if [ "$BIN_ARCH" = "unknown" ]; then
    error "Unsupported architecture: $ARCH"
    exit 1
fi

if [ "$EXEC_MODE" = "unsupported" ] || [ -z "$INSTALL_BIN_DIR" ] || [ -z "$INSTALL_CLIPROXY_DIR" ]; then
    error "Manual mode requires a writable install layout."
    exit 1
fi

warn "Installing in manual mode: no boot-managed auto-start will be configured."
confirm_platform || exit 1

BIN_SRC="$ROOT_DIR/binaries/$BIN_ARCH"
CONFIGS="$ROOT_DIR/configs"

check_binaries_exist "$BIN_SRC" || exit 1
check_disk_space 100 || exit 1
check_ram 256 || exit 1

if [ "${ONLY_BINARY:-0}" = "1" ]; then
    info "ONLY_BINARY=1 detected; refreshing installed binaries and management UI only"
    run_only_binary_update "$BIN_SRC" "$CONFIGS" "$INSTALL_BIN_DIR/zeroclaw" "$INSTALL_CLIPROXY_DIR/cli-proxy-api" "$INSTALL_CLIPROXY_DIR" stop_manual_services_for_only_binary start_manual_services || exit 1
    step "Verification"
    verify_services
    exit 0
fi

step "Telegram config (mandatory)"
ask_telegram_config || exit 1

cleanup_existing_installation

init_manual_runtime_paths

step "Installing binaries"
mkdir -p "$INSTALL_BIN_DIR" "$INSTALL_CLIPROXY_DIR" "$MANUAL_PID_DIR" "$MANUAL_LOG_DIR"

install_binary_from_stage "$BIN_SRC/zeroclaw" "$INSTALL_BIN_DIR/zeroclaw" "zeroclaw" || exit 1
chmod +x "$INSTALL_BIN_DIR/zeroclaw"
info "  $INSTALL_BIN_DIR/zeroclaw installed"

install_binary_from_stage "$BIN_SRC/cli-proxy-api" "$INSTALL_CLIPROXY_DIR/cli-proxy-api" "cli-proxy-api" || exit 1
chmod +x "$INSTALL_CLIPROXY_DIR/cli-proxy-api"
info "  $INSTALL_CLIPROXY_DIR/cli-proxy-api installed"

install_zeroclaw_config "$CONFIGS" || exit 1
install_cliproxy_config "$CONFIGS" "$INSTALL_CLIPROXY_DIR" || exit 1
inject_telegram_config || exit 1

if [ "$INSTALL_CLIPROXY_DIR" != "/opt/cliproxyapi" ]; then
    set_cliproxy_auth_dir "$INSTALL_CLIPROXY_DIR/config.yaml" "$INSTALL_CLIPROXY_DIR/auth" || exit 1
fi

set_zeroclaw_provider_port 8317 || exit 1

step "Installing manual service scripts"
cat > "$MANUAL_SCRIPT_DIR/cliproxyapi-service" <<EOF
#!/bin/sh
PROG="$INSTALL_CLIPROXY_DIR/cli-proxy-api"
CONFIG="$INSTALL_CLIPROXY_DIR/config.yaml"
PIDFILE="$MANUAL_PID_DIR/cliproxyapi.pid"
LOGFILE="$MANUAL_LOG_DIR/cliproxyapi.log"

is_alive() {
    [ -f "\$1" ] && kill -0 "\$(cat "\$1")" 2>/dev/null
}

start() {
    if is_alive "\$PIDFILE"; then
        echo "CLIProxyAPI already running (PID \$(cat "\$PIDFILE"))"
        return 0
    fi

    mkdir -p "$(dirname "$MANUAL_PID_DIR/cliproxyapi.pid")" "$(dirname "$MANUAL_LOG_DIR/cliproxyapi.log")"
    "\$PROG" --config "\$CONFIG" >> "\$LOGFILE" 2>&1 &
    echo \$! > "\$PIDFILE"
    echo "CLIProxyAPI started (PID \$!)"
}

stop() {
    if is_alive "\$PIDFILE"; then
        kill "\$(cat "\$PIDFILE")" 2>/dev/null || true
    fi
    rm -f "\$PIDFILE"

    killall cli-proxy-api 2>/dev/null || true
}

status() {
    if is_alive "\$PIDFILE"; then
        echo "CLIProxyAPI is running (PID \$(cat "\$PIDFILE"))"
    else
        echo "CLIProxyAPI is not running"
    fi
}

case "\$1" in
    start) start ;;
    stop) stop ;;
    restart) stop; sleep 1; start ;;
    status) status ;;
    *) echo "Usage: \$0 {start|stop|restart|status}" ; exit 1 ;;
esac
EOF
chmod +x "$MANUAL_SCRIPT_DIR/cliproxyapi-service"
info "  $MANUAL_SCRIPT_DIR/cliproxyapi-service"

cat > "$MANUAL_SCRIPT_DIR/zeroclaw-service" <<EOF
#!/bin/sh
PROG="$INSTALL_BIN_DIR/zeroclaw"
CONFIG_DIR="/root/.zeroclaw"
PIDFILE="$MANUAL_PID_DIR/zeroclaw.pid"
LOGFILE="$MANUAL_LOG_DIR/zeroclaw.log"
PATH_PREFIX="$INSTALL_BIN_DIR"

is_alive() {
    [ -f "\$1" ] && kill -0 "\$(cat "\$1")" 2>/dev/null
}

start() {
    if is_alive "\$PIDFILE"; then
        echo "ZeroClaw already running (PID \$(cat "\$PIDFILE"))"
        return 0
    fi

    mkdir -p "$(dirname "$MANUAL_PID_DIR/zeroclaw.pid")" "$(dirname "$MANUAL_LOG_DIR/zeroclaw.log")"
    SHELL=/bin/sh HOME=/root PATH="\$PATH_PREFIX:/opt/sbin:/opt/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        "\$PROG" daemon --config-dir "\$CONFIG_DIR" >> "\$LOGFILE" 2>&1 &
    echo \$! > "\$PIDFILE"
    echo "ZeroClaw started (PID \$!)"
}

stop() {
    if is_alive "\$PIDFILE"; then
        kill "\$(cat "\$PIDFILE")" 2>/dev/null || true
    fi
    rm -f "\$PIDFILE"
    killall zeroclaw 2>/dev/null || true
}

status() {
    if is_alive "\$PIDFILE"; then
        echo "ZeroClaw is running (PID \$(cat "\$PIDFILE"))"
    else
        echo "ZeroClaw is not running"
    fi
}

case "\$1" in
    start) start ;;
    stop) stop ;;
    restart) stop; sleep 1; start ;;
    status) status ;;
    *) echo "Usage: \$0 {start|stop|restart|status}" ; exit 1 ;;
esac
EOF
chmod +x "$MANUAL_SCRIPT_DIR/zeroclaw-service"
info "  $MANUAL_SCRIPT_DIR/zeroclaw-service"

start_manual_services || exit 1

step "Encrypting credentials"
"$INSTALL_BIN_DIR/zeroclaw" config encrypt --config-dir /root/.zeroclaw 2>/dev/null || warn "Config encryption skipped"

step "Verification"
verify_services

echo ""
warn "Manual mode does not enable auto-start. Use the generated service scripts after reboot."
info "Done! Send a message to your Telegram bot to test."
