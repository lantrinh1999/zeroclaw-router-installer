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

step "Platform detection"
detect_platform
PLATFORM="manual"
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

step "Telegram config (mandatory)"
ask_telegram_config || exit 1

cleanup_existing_installation

MANUAL_SCRIPT_DIR="$INSTALL_BIN_DIR"
MANUAL_PID_DIR=$(first_writable_path /var/run /opt/var/run /tmp)
MANUAL_LOG_DIR=$(first_writable_path /var/log /opt/var/log /tmp)
[ -n "$MANUAL_PID_DIR" ] || MANUAL_PID_DIR="/tmp"
[ -n "$MANUAL_LOG_DIR" ] || MANUAL_LOG_DIR="/tmp"

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

CLIPROXY_PUBLIC_PORT="8317"
if command -v socat >/dev/null 2>&1; then
    info "socat detected, keeping public bridge on port 8317"
else
    warn "socat not found, falling back to direct CLIProxyAPI port 8318"
    CLIPROXY_PUBLIC_PORT="8318"
    set_zeroclaw_provider_port 8318 || exit 1
fi

step "Installing manual service scripts"
cat > "$MANUAL_SCRIPT_DIR/cliproxyapi-service" <<EOF
#!/bin/sh
PROG="$INSTALL_CLIPROXY_DIR/cli-proxy-api"
CONFIG="$INSTALL_CLIPROXY_DIR/config.yaml"
PIDFILE="$MANUAL_PID_DIR/cliproxyapi.pid"
LOGFILE="$MANUAL_LOG_DIR/cliproxyapi.log"
SOCAT_PIDFILE="$MANUAL_PID_DIR/cliproxyapi-bridge.pid"
PUBLIC_PORT="$CLIPROXY_PUBLIC_PORT"

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

    if [ "\$PUBLIC_PORT" = "8317" ] && command -v socat >/dev/null 2>&1; then
        socat TCP4-LISTEN:8317,fork,reuseaddr TCP4:127.0.0.1:8318 >> "\$LOGFILE" 2>&1 &
        echo \$! > "\$SOCAT_PIDFILE"
        echo "socat bridge started (PID \$!)"
    fi
}

stop() {
    if is_alive "\$SOCAT_PIDFILE"; then
        kill "\$(cat "\$SOCAT_PIDFILE")" 2>/dev/null || true
    fi
    rm -f "\$SOCAT_PIDFILE"

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

step "Starting services"
prepare_fresh_service_start 10

"$MANUAL_SCRIPT_DIR/cliproxyapi-service" start || exit 1
if wait_for_port_listening "$CLIPROXY_PUBLIC_PORT" 15 || wait_for_port_listening 8318 15; then
    info "CLIProxyAPI is running on port $CLIPROXY_PUBLIC_PORT"
else
    warn "CLIProxyAPI may not have started. Check: $MANUAL_LOG_DIR/cliproxyapi.log"
    show_port_snapshot 8317 8318
fi

"$MANUAL_SCRIPT_DIR/zeroclaw-service" start || exit 1
sleep 3

if is_process_running zeroclaw; then
    info "ZeroClaw is running"
else
    warn "ZeroClaw may not have started. Check: $MANUAL_LOG_DIR/zeroclaw.log"
fi

step "Encrypting credentials"
"$INSTALL_BIN_DIR/zeroclaw" config encrypt --config-dir /root/.zeroclaw 2>/dev/null || warn "Config encryption skipped"

step "Verification"
verify_services

echo ""
warn "Manual mode does not enable auto-start. Use the generated service scripts after reboot."
info "Done! Send a message to your Telegram bot to test."
