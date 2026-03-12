#!/bin/sh
# =======================================================
# ZeroClaw Common Library
# =======================================================
# Shared functions for all platform installers.
# Usage: . "$SCRIPT_DIR/common.sh" (source from install/uninstall scripts)

# -- Log File ----------------------------------------
LOG_FILE="/tmp/zeroclaw-install.log"
: > "$LOG_FILE"  # Clear log file at start

# -- Colors (ash/sh compatible) ----------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# -- Logging (stdout + file) ------------------------
_log() {
    # Usage: _log "LEVEL" "color" "message"
    LEVEL="$1"; COLOR="$2"; MSG="$3"
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    # Console (colored)
    printf "${COLOR}[${LEVEL}]${NC} %s\n" "$MSG"
    # File (plain, with timestamp)
    echo "[$TIMESTAMP] [$LEVEL] $MSG" >> "$LOG_FILE"
}

info()    { _log "INFO" "$GREEN" "$1"; }
warn()    { _log "WARN" "$YELLOW" "$1"; }
error()   { _log "ERROR" "$RED" "$1"; }
debug()   { _log "DEBUG" "$CYAN" "$1"; }
header()  {
    printf "\n${BOLD}${CYAN}=== %s ===${NC}\n\n" "$1"
    echo "" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') === $1 ===" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

# -- Step tracking -----------------------------------
_step_num=0
step() {
    _step_num=$((_step_num + 1))
    _log "STEP" "$BOLD" "[$_step_num] $1"
}

# -- Command tracing (run + log) --------------------
run_cmd() {
    # Usage: run_cmd "description" command arg1 arg2 ...
    DESC="$1"; shift
    debug "  CMD: $*"
    OUTPUT=$("$@" 2>&1) || {
        RC=$?
        error "  FAILED (exit $RC): $*"
        [ -n "$OUTPUT" ] && echo "  OUTPUT: $OUTPUT" >> "$LOG_FILE"
        return $RC
    }
    [ -n "$OUTPUT" ] && debug "  OUTPUT: $OUTPUT"
    return 0
}

# -- User Input (non-interactive safe) ---------------
ask_input() {
    # Usage: ask_input "prompt" VARIABLE
    # In non-interactive mode (SKIP_CONFIRM=1), sets empty value
    if [ "$SKIP_CONFIRM" = "1" ] || [ ! -t 0 ]; then
        debug "ask_input skipped (non-interactive): $1"
        eval "$2=''"
        return 0
    fi
    printf "${CYAN}[INPUT]${NC} %s: " "$1"
    read "$2"
}

confirm() {
    # Usage: confirm "question" -> returns 0 (yes) or 1 (no)
    # In non-interactive mode, auto-confirms (returns 0)
    if [ "$SKIP_CONFIRM" = "1" ] || [ ! -t 0 ]; then
        debug "confirm auto-yes (non-interactive): $1"
        return 0
    fi
    printf "${CYAN}[CONFIRM]${NC} %s [Y/n]: " "$1"
    read _REPLY
    case "$_REPLY" in
        n|N) return 1 ;;
        *)   return 0 ;;
    esac
}

confirm_strict() {
    # Usage: confirm_strict "question" -> returns 0 (yes) or 1 (no)
    # In non-interactive mode, auto-rejects (returns 1) for safety
    if [ "$SKIP_CONFIRM" = "1" ] || [ ! -t 0 ]; then
        debug "confirm_strict auto-no (non-interactive): $1"
        return 1
    fi
    printf "${CYAN}[CONFIRM]${NC} %s [y/N]: " "$1"
    read _REPLY
    case "$_REPLY" in
        y|Y) return 0 ;;
        *)   return 1 ;;
    esac
}

# =======================================================
# Platform Detection
# =======================================================

detect_arch() {
    ARCH=$(uname -m)
    case "$ARCH" in
        aarch64)        BIN_ARCH="aarch64" ;;
        mips|mipsel)    BIN_ARCH="mips32r2" ;;
        *)              BIN_ARCH="unknown" ;;
    esac
    debug "detect_arch: ARCH=$ARCH, BIN_ARCH=$BIN_ARCH"
}

detect_os() {
    # Structure-based detection: procd + /etc/init.d + /etc/config = OpenWrt-family
    # Covers: OpenWrt, kWrt, ImmortalWrt, and any procd-based firmware
    if pidof procd >/dev/null 2>&1 && [ -d /etc/init.d ] && [ -d /etc/config ]; then
        OS_TYPE="openwrt"
        # Try to get OS name from known release files
        if [ -f /etc/openwrt_release ]; then
            OS_NAME=$(grep DISTRIB_DESCRIPTION /etc/openwrt_release 2>/dev/null | cut -d"'" -f2)
        elif [ -f /etc/kwrt_release ]; then
            OS_NAME=$(grep DISTRIB_DESCRIPTION /etc/kwrt_release 2>/dev/null | cut -d"'" -f2)
        fi
        # Fallback to os-release
        [ -z "$OS_NAME" ] && OS_NAME=$(cat /etc/os-release 2>/dev/null | grep "^PRETTY_NAME=" | cut -d'"' -f2)
        [ -z "$OS_NAME" ] && OS_NAME="OpenWrt-based (custom)"
    elif [ -f /etc/buildroot-release ] || [ -d /usr/share/buildroot ]; then
        OS_TYPE="buildroot"
        OS_NAME="Buildroot Linux"
    else
        OS_TYPE="linux"
        OS_NAME=$(cat /etc/os-release 2>/dev/null | grep "^PRETTY_NAME=" | cut -d'"' -f2)
        [ -z "$OS_NAME" ] && OS_NAME="Linux (unknown distro)"
    fi
    debug "detect_os: OS_TYPE=$OS_TYPE, OS_NAME=$OS_NAME"
}

detect_init() {
    if pidof procd >/dev/null 2>&1; then
        INIT_TYPE="procd"
    elif [ -d /opt/etc/init.d ]; then
        INIT_TYPE="sysv-entware"
    elif [ -d /etc/init.d ]; then
        INIT_TYPE="sysv"
    else
        INIT_TYPE="unknown"
    fi
    debug "detect_init: INIT_TYPE=$INIT_TYPE"
}

detect_entware() {
    if [ -x /opt/bin/opkg ]; then
        ENTWARE_INSTALLED=1
        ENTWARE_OPKG="/opt/bin/opkg"
    else
        ENTWARE_INSTALLED=0
        ENTWARE_OPKG=""
    fi
    debug "detect_entware: ENTWARE_INSTALLED=$ENTWARE_INSTALLED"
}

detect_platform() {
    debug "Running platform detection..."
    detect_arch
    detect_os
    detect_init
    detect_entware

    # Determine platform type
    if [ "$OS_TYPE" = "openwrt" ]; then
        PLATFORM="procd"
    elif [ "$ENTWARE_INSTALLED" = "1" ] || [ "$OS_TYPE" = "buildroot" ] || [ "$OS_TYPE" = "linux" ]; then
        PLATFORM="entware"
    else
        PLATFORM="unknown"
    fi

    # Get additional system info
    KERNEL_VER=$(uname -r)
    RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    RAM_MB=$((RAM_KB / 1024))

    # Disk space (try /overlay first for OpenWrt, then /opt, then /)
    if [ "$PLATFORM" = "procd" ]; then
        DISK_FREE_KB=$(df /overlay 2>/dev/null | tail -1 | awk '{print $4}')
    elif [ -d /opt ]; then
        DISK_FREE_KB=$(df /opt 2>/dev/null | tail -1 | awk '{print $4}')
    fi
    [ -z "$DISK_FREE_KB" ] && DISK_FREE_KB=$(df / 2>/dev/null | tail -1 | awk '{print $4}')
    DISK_FREE_MB=$((DISK_FREE_KB / 1024))

    debug "Platform detection complete: PLATFORM=$PLATFORM, RAM=${RAM_MB}MB, DISK=${DISK_FREE_MB}MB"
}

show_platform_info() {
    echo ""
    echo "--- Platform Detection ---"
    echo "  Architecture:  $ARCH ($BIN_ARCH)"
    echo "  OS:            $OS_NAME"
    echo "  OS Type:       $OS_TYPE"
    echo "  Kernel:        $KERNEL_VER"
    echo "  Init System:   $INIT_TYPE"
    echo "  Entware:       $([ "$ENTWARE_INSTALLED" = "1" ] && echo "Installed" || echo "Not installed")"
    echo "  RAM:           ${RAM_MB}MB"
    echo "  Disk Free:     ${DISK_FREE_MB}MB"
    echo "  Platform:      $PLATFORM"
    echo ""

    # Also log to file
    debug "PLATFORM_INFO: arch=$ARCH/$BIN_ARCH os=$OS_NAME/$OS_TYPE kernel=$KERNEL_VER init=$INIT_TYPE ram=${RAM_MB}MB disk=${DISK_FREE_MB}MB platform=$PLATFORM"
}

confirm_platform() {
    show_platform_info

    if [ "$PLATFORM" = "unknown" ]; then
        error "Cannot determine platform. Arch=$ARCH, OS=$OS_TYPE"
        return 1
    fi

    if [ "$BIN_ARCH" = "unknown" ]; then
        error "Unsupported architecture: $ARCH"
        return 1
    fi

    # Skip interactive confirm when called from setup.sh (already confirmed locally)
    if [ "$SKIP_CONFIRM" = "1" ]; then
        info "Platform confirmed (via setup.sh)"
        return 0
    fi

    if ! confirm "Thông tin trên có chính xác không? Tiếp tục cài đặt?"; then
        error "Installation cancelled by user."
        return 1
    fi

    return 0
}

# =======================================================
# Pre-checks
# =======================================================

check_disk_space() {
    MIN_MB="${1:-100}"
    if [ "$DISK_FREE_MB" -lt "$MIN_MB" ]; then
        error "Not enough disk space. Need ${MIN_MB}MB, have ${DISK_FREE_MB}MB"
        return 1
    fi
    info "Disk space OK: ${DISK_FREE_MB}MB free"
    return 0
}

check_ram() {
    MIN_MB="${1:-256}"
    if [ "$RAM_MB" -lt "$MIN_MB" ]; then
        error "Not enough RAM. Need ${MIN_MB}MB, have ${RAM_MB}MB"
        return 1
    fi
    info "RAM OK: ${RAM_MB}MB"
    return 0
}

check_binaries_exist() {
    # Usage: check_binaries_exist /path/to/binaries/arch
    BIN_SRC_DIR="$1"
    debug "Checking binaries in: $BIN_SRC_DIR"
    if [ ! -f "$BIN_SRC_DIR/zeroclaw" ]; then
        error "Missing: $BIN_SRC_DIR/zeroclaw"
        return 1
    fi
    if [ ! -f "$BIN_SRC_DIR/cli-proxy-api" ]; then
        error "Missing: $BIN_SRC_DIR/cli-proxy-api"
        return 1
    fi
    ZC_SIZE=$(ls -la "$BIN_SRC_DIR/zeroclaw" | awk '{print $5}')
    CP_SIZE=$(ls -la "$BIN_SRC_DIR/cli-proxy-api" | awk '{print $5}')
    info "Binaries found: zeroclaw (${ZC_SIZE}B), cli-proxy-api (${CP_SIZE}B)"
    return 0
}

# =======================================================
# Config Installation (shared between platforms)
# =======================================================

install_zeroclaw_config() {
    CONFIGS_DIR="$1"
    step "Installing ZeroClaw config..."

    debug "Creating ZeroClaw directories..."
    mkdir -p /root/.zeroclaw/workspace/skills
    mkdir -p /root/.zeroclaw/workspace/memory
    mkdir -p /root/.zeroclaw/workspace/sessions
    mkdir -p /root/.zeroclaw/workspace/state

    # Backup existing config
    if [ -f /root/.zeroclaw/config.toml ]; then
        warn "Existing config.toml found. Backing up to config.toml.bak"
        cp /root/.zeroclaw/config.toml /root/.zeroclaw/config.toml.bak
    fi

    debug "Copying config.toml from $CONFIGS_DIR/zeroclaw/config.toml"
    if cp "$CONFIGS_DIR/zeroclaw/config.toml" /root/.zeroclaw/config.toml; then
        info "  config.toml installed"
    else
        error "  FAILED to copy config.toml"
        return 1
    fi

    # Copy workspace files (don't overwrite existing)
    for f in "$CONFIGS_DIR"/zeroclaw/workspace/*.md; do
        [ -f "$f" ] || continue
        fname=$(basename "$f")
        if [ ! -f "/root/.zeroclaw/workspace/$fname" ]; then
            cp "$f" "/root/.zeroclaw/workspace/$fname"
            debug "  workspace/$fname (new)"
        else
            debug "  workspace/$fname (kept existing)"
        fi
    done

    # Copy skills (always overwrite -- they're definitions)
    if [ -d "$CONFIGS_DIR/zeroclaw/workspace/skills" ]; then
        cp -r "$CONFIGS_DIR/zeroclaw/workspace/skills/"* /root/.zeroclaw/workspace/skills/ 2>/dev/null
        SKILL_COUNT=$(ls -d /root/.zeroclaw/workspace/skills/*/ 2>/dev/null | wc -l)
        info "  $SKILL_COUNT skills installed"
    else
        warn "  No skills directory found in $CONFIGS_DIR/zeroclaw/workspace/skills"
    fi
}

install_cliproxy_config() {
    CONFIGS_DIR="$1"
    CLIPROXY_DIR="$2"  # Install destination (e.g., /opt/cliproxyapi)

    step "Installing CLIProxyAPI config..."

    debug "Creating CLIProxyAPI directories: $CLIPROXY_DIR/{auth,static}"
    mkdir -p "$CLIPROXY_DIR/auth"
    mkdir -p "$CLIPROXY_DIR/static"

    # Backup existing config
    if [ -f "$CLIPROXY_DIR/config.yaml" ]; then
        warn "Existing CLIProxyAPI config found. Backing up."
        cp "$CLIPROXY_DIR/config.yaml" "$CLIPROXY_DIR/config.yaml.bak"
    fi

    debug "Copying config.yaml from $CONFIGS_DIR/cliproxy/config.yaml"
    if cp "$CONFIGS_DIR/cliproxy/config.yaml" "$CLIPROXY_DIR/config.yaml"; then
        info "  config.yaml installed"
    else
        error "  FAILED to copy config.yaml"
        return 1
    fi

    # Copy management UI
    if cp "$CONFIGS_DIR/cliproxy/static/management.html" "$CLIPROXY_DIR/static/management.html" 2>/dev/null; then
        info "  management.html installed"
    else
        warn "  management.html not found in $CONFIGS_DIR/cliproxy/static/"
    fi

    # Copy all auth files (only if auth dir is empty)
    AUTH_COUNT=$(ls "$CLIPROXY_DIR/auth/"*.json 2>/dev/null | wc -l)
    if [ "$AUTH_COUNT" = "0" ]; then
        SRC_AUTH_COUNT=$(ls "$CONFIGS_DIR/cliproxy/auth/"*.json 2>/dev/null | wc -l)
        if [ "$SRC_AUTH_COUNT" -gt 0 ]; then
            cp "$CONFIGS_DIR/cliproxy/auth/"*.json "$CLIPROXY_DIR/auth/" 2>/dev/null
            COPIED=$(ls "$CLIPROXY_DIR/auth/"*.json 2>/dev/null | wc -l)
            info "  $COPIED auth file(s) copied to $CLIPROXY_DIR/auth/"
        else
            warn "No auth files found in $CONFIGS_DIR/cliproxy/auth/"
        fi
    else
        info "  Auth dir has $AUTH_COUNT credential(s), keeping existing"
    fi
}

# =======================================================
# Telegram Config Injection
# =======================================================

test_telegram_message() {
    # Usage: test_telegram_message BOT_TOKEN USER_ID
    # Returns 0 if message sent successfully, 1 otherwise
    _TG_TOKEN="$1"
    _TG_USER="$2"
    _TG_URL="https://api.telegram.org/bot${_TG_TOKEN}/sendMessage"
    _TG_MSG="ZeroClaw installer: Ket noi Telegram thanh cong."

    debug "Testing Telegram API: token=***${_TG_TOKEN##${_TG_TOKEN%????}}, user=$_TG_USER"

    # Try wget first, fallback to curl
    if command -v wget >/dev/null 2>&1; then
        debug "Using wget for Telegram API call"
        _TG_RESULT=$(wget -qO- --timeout=15 --post-data="chat_id=${_TG_USER}&text=${_TG_MSG}" "$_TG_URL" 2>&1) || {
            debug "wget failed, trying curl..."
            if command -v curl >/dev/null 2>&1; then
                _TG_RESULT=$(curl -s --connect-timeout 10 --max-time 3 -X POST "$_TG_URL" -d "chat_id=${_TG_USER}&text=${_TG_MSG}" 2>&1)
            else
                error "wget failed and curl not available"
                return 1
            fi
        }
    elif command -v curl >/dev/null 2>&1; then
        debug "Using curl for Telegram API call"
        _TG_RESULT=$(curl -s --connect-timeout 10 --max-time 3 -X POST "$_TG_URL" -d "chat_id=${_TG_USER}&text=${_TG_MSG}" 2>&1)
    else
        error "Neither wget nor curl available -- cannot test Telegram"
        return 1
    fi

    debug "Telegram API response: $_TG_RESULT"

    # Check if response contains "ok":true
    if echo "$_TG_RESULT" | grep -q '"ok":true'; then
        info "Telegram test message sent successfully!"
        return 0
    else
        # Try to extract error description
        _TG_ERR=$(echo "$_TG_RESULT" | grep -o '"description":"[^"]*"' | cut -d'"' -f4)
        [ -z "$_TG_ERR" ] && _TG_ERR="$_TG_RESULT"
        error "Telegram test failed: $_TG_ERR"
        return 1
    fi
}

ask_telegram_config() {
    # Non-interactive mode (from setup.sh): token/user ID must be provided via env
    if [ "$SKIP_CONFIRM" = "1" ] || [ ! -t 0 ]; then
        if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_USER_ID" ]; then
            error "Telegram Bot Token and User ID are required!"
            error "Pass via env: TELEGRAM_BOT_TOKEN='...' TELEGRAM_USER_ID='...' sh install.sh"
            return 1
        fi
        info "Telegram config received from setup.sh (token=***${TELEGRAM_BOT_TOKEN##${TELEGRAM_BOT_TOKEN%????}})"
        debug "TELEGRAM_BOT_TOKEN is set (length=${#TELEGRAM_BOT_TOKEN})"
        debug "TELEGRAM_USER_ID=$TELEGRAM_USER_ID"
        return 0
    fi

    # Interactive mode: loop until valid token + user ID + test passes
    while true; do
        printf "${CYAN}[INPUT]${NC} Telegram Bot Token (bat buoc): "
        read TELEGRAM_BOT_TOKEN
        if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
            warn "Bot Token la bat buoc. Vui long nhap lai."
            continue
        fi

        printf "${CYAN}[INPUT]${NC} Telegram User ID (bat buoc): "
        read TELEGRAM_USER_ID
        if [ -z "$TELEGRAM_USER_ID" ]; then
            warn "User ID la bat buoc. Vui long nhap lai."
            continue
        fi

        # Test send message
        info "Dang gui tin nhan test qua Telegram..."
        if test_telegram_message "$TELEGRAM_BOT_TOKEN" "$TELEGRAM_USER_ID"; then
            info "Kiem tra Telegram cua ban -- ban da nhan duoc tin nhan?"
            if confirm "Ban da nhan duoc tin nhan test?"; then
                return 0
            else
                warn "Vui long nhap lai thong tin Telegram."
            fi
        else
            warn "Khong gui duoc tin nhan. Kiem tra lai Bot Token va User ID."
            if ! confirm "Nhap lai?"; then
                error "Telegram is required. Installation cancelled."
                return 1
            fi
        fi
    done
}

inject_telegram_config() {
    CONFIG="/root/.zeroclaw/config.toml"

    if [ ! -f "$CONFIG" ]; then
        error "Cannot inject Telegram config: $CONFIG not found"
        return 1
    fi

    info "Configuring Telegram bot..."
    sed -i "s|__TELEGRAM_BOT_TOKEN__|$TELEGRAM_BOT_TOKEN|g" "$CONFIG"
    sed -i "s|__TELEGRAM_USER_ID__|$TELEGRAM_USER_ID|g" "$CONFIG"
    debug "Telegram config injected into $CONFIG"
}

# =======================================================
# Service Control
# =======================================================

SERVICE_PORTS="8317 8318 3080"

socket_table() {
    if command -v netstat >/dev/null 2>&1; then
        netstat -tlnp 2>/dev/null || netstat -tln 2>/dev/null
        return 0
    fi
    if command -v ss >/dev/null 2>&1; then
        ss -tlnp 2>/dev/null || ss -tln 2>/dev/null
        return 0
    fi
    return 1
}

is_port_listening() {
    _PORT="$1"
    socket_table | grep -Eq "[:.]${_PORT}[[:space:]]"
}

port_listener_line() {
    _PORT="$1"
    _LINE=$(socket_table | grep -E "[:.]${_PORT}[[:space:]]" | head -n 1)
    [ -n "$_LINE" ] && echo "$_LINE" || echo "NOT LISTENING"
}

busy_port_count() {
    _COUNT=0
    for _PORT in "$@"; do
        if is_port_listening "$_PORT"; then
            _COUNT=$((_COUNT + 1))
        fi
    done
    echo "$_COUNT"
}

show_port_snapshot() {
    for _PORT in "$@"; do
        _LINE=$(port_listener_line "$_PORT")
        if [ "$_LINE" != "NOT LISTENING" ]; then
            debug "  port $_PORT: $_LINE"
        fi
    done
}

wait_for_ports_free() {
    _TIMEOUT="$1"
    shift
    _WAIT=0
    while [ "$_WAIT" -lt "$_TIMEOUT" ]; do
        _BUSY=$(busy_port_count "$@")
        [ "$_BUSY" = "0" ] && return 0
        debug "  Waiting for $_BUSY port(s) to free... (${_WAIT}s)"
        sleep 1
        _WAIT=$((_WAIT + 1))
    done
    _BUSY=$(busy_port_count "$@")
    [ "$_BUSY" = "0" ]
}

wait_for_port_listening() {
    _PORT="$1"
    _TIMEOUT="${2:-15}"
    _WAIT=0
    while [ "$_WAIT" -lt "$_TIMEOUT" ]; do
        if is_port_listening "$_PORT"; then
            debug "Port $_PORT detected after ${_WAIT}s"
            return 0
        fi
        sleep 1
        _WAIT=$((_WAIT + 1))
    done
    return 1
}

wait_for_port_with_process_guard() {
    _PORT="$1"
    _PROC="$2"
    _TIMEOUT="${3:-15}"
    _WAIT=0
    while [ "$_WAIT" -lt "$_TIMEOUT" ]; do
        if is_port_listening "$_PORT"; then
            debug "Port $_PORT detected after ${_WAIT}s"
            return 0
        fi
        if [ "$_WAIT" -gt 3 ] && ! is_process_running "$_PROC"; then
            debug "$_PROC process died, no point waiting for port $_PORT"
            return 1
        fi
        sleep 1
        _WAIT=$((_WAIT + 1))
    done
    return 1
}

process_pids() {
    pidof "$1" 2>/dev/null || true
}

is_process_running() {
    [ -n "$(process_pids "$1")" ]
}

process_count() {
    _PIDS=$(process_pids "$1")
    if [ -n "$_PIDS" ]; then
        echo "$_PIDS" | awk '{print NF}'
    else
        echo "0"
    fi
}

total_process_count() {
    _TOTAL=0
    for _PROC in "$@"; do
        _COUNT=$(process_count "$_PROC")
        _TOTAL=$((_TOTAL + _COUNT))
    done
    echo "$_TOTAL"
}

wait_for_processes_exit() {
    _TIMEOUT="$1"
    shift
    _WAIT=0
    while [ "$_WAIT" -lt "$_TIMEOUT" ]; do
        _REMAINING=$(total_process_count "$@")
        [ "$_REMAINING" = "0" ] && return 0
        debug "  Waiting for $_REMAINING process(es) to terminate... (${_WAIT}s)"
        sleep 1
        _WAIT=$((_WAIT + 1))
    done
    _REMAINING=$(total_process_count "$@")
    [ "$_REMAINING" = "0" ]
}

runtime_residue_present() {
    is_process_running zeroclaw && return 0
    is_process_running cli-proxy-api && return 0
    for _PORT in $SERVICE_PORTS; do
        is_port_listening "$_PORT" && return 0
    done
    return 1
}

delete_procd_service_state() {
    if ! command -v ubus >/dev/null 2>&1; then
        debug "ubus not available, skipping procd state cleanup"
        return 0
    fi

    debug "Deleting services from procd state..."
    ubus call service delete '{"name":"cliproxyapi"}' 2>/dev/null && debug "  procd: cliproxyapi deleted" || debug "  procd: cliproxyapi not tracked"
    ubus call service delete '{"name":"zeroclaw"}' 2>/dev/null && debug "  procd: zeroclaw deleted" || debug "  procd: zeroclaw not tracked"
}

force_release_service_runtime() {
    _TIMEOUT="${1:-15}"

    debug "Force killing remaining service processes..."
    killall zeroclaw cli-proxy-api socat 2>/dev/null || true
    rm -f /var/run/cliproxyapi.pid /var/run/zeroclaw.pid /opt/var/run/cliproxyapi.pid /opt/var/run/zeroclaw.pid 2>/dev/null

    if command -v fuser >/dev/null 2>&1; then
        for _PORT in $SERVICE_PORTS; do
            fuser -k "${_PORT}/tcp" 2>/dev/null && debug "  fuser killed process on $_PORT" || true
        done
    fi

    if wait_for_processes_exit "$_TIMEOUT" zeroclaw cli-proxy-api; then
        debug "Service processes are fully stopped"
    else
        warn "Some service processes may still be running after ${_TIMEOUT}s"
    fi

    if wait_for_ports_free "$_TIMEOUT" $SERVICE_PORTS; then
        debug "Service ports are free"
    else
        warn "Service ports still in use after ${_TIMEOUT}s"
        show_port_snapshot $SERVICE_PORTS
    fi
}

prepare_fresh_service_start() {
    _TIMEOUT="${1:-10}"
    if runtime_residue_present; then
        warn "Detected stale runtime state before start, forcing cleanup..."
        show_port_snapshot $SERVICE_PORTS
    fi
    force_release_service_runtime "$_TIMEOUT"
}

stop_existing_services() {
    step "Stopping existing services (if any)..."

    # Disable services FIRST to prevent procd from respawning during reinstall
    debug "Disabling services to prevent procd respawn..."
    /etc/init.d/cliproxyapi disable 2>/dev/null || true
    /etc/init.d/zeroclaw disable 2>/dev/null || true

    debug "Stopping services via init scripts..."
    /etc/init.d/zeroclaw stop 2>/dev/null && debug "  zeroclaw stopped via /etc/init.d" || debug "  zeroclaw not running via /etc/init.d"
    /etc/init.d/cliproxyapi stop 2>/dev/null && debug "  cliproxyapi stopped via /etc/init.d" || debug "  cliproxyapi not running via /etc/init.d"
    /opt/etc/init.d/S99zeroclaw stop 2>/dev/null && debug "  zeroclaw stopped via /opt init.d" || true
    /opt/etc/init.d/S98cliproxyapi stop 2>/dev/null && debug "  cliproxyapi stopped via /opt init.d" || true

    # Prevent procd from respawning stale instances
    delete_procd_service_state

    force_release_service_runtime 10
}

cleanup_existing_installation() {
    HAS_FILES=0
    [ -f /usr/bin/zeroclaw ] && HAS_FILES=1
    [ -f /opt/bin/zeroclaw ] && HAS_FILES=1
    [ -f /opt/cliproxyapi/cli-proxy-api ] && HAS_FILES=1
    [ -f /etc/init.d/zeroclaw ] && HAS_FILES=1
    [ -f /etc/init.d/cliproxyapi ] && HAS_FILES=1
    [ -f /opt/etc/init.d/S99zeroclaw ] && HAS_FILES=1
    [ -f /opt/etc/init.d/S98cliproxyapi ] && HAS_FILES=1

    if [ "$HAS_FILES" = "0" ] && ! runtime_residue_present; then
        debug "No existing installation found, skipping cleanup"
        return 0
    fi

    step "Detected existing installation -- full teardown before reinstall..."

    debug "Stopping services via init.d..."
    /etc/init.d/cliproxyapi stop 2>/dev/null && debug "  cliproxyapi stopped via /etc/init.d" || true
    /etc/init.d/zeroclaw stop 2>/dev/null && debug "  zeroclaw stopped via /etc/init.d" || true
    /opt/etc/init.d/S98cliproxyapi stop 2>/dev/null && debug "  cliproxyapi stopped via /opt init.d" || true
    /opt/etc/init.d/S99zeroclaw stop 2>/dev/null && debug "  zeroclaw stopped via /opt init.d" || true

    delete_procd_service_state

    debug "Disabling auto-start..."
    /etc/init.d/cliproxyapi disable 2>/dev/null || true
    /etc/init.d/zeroclaw disable 2>/dev/null || true

    debug "Removing init scripts..."
    rm -f /etc/init.d/cliproxyapi /etc/init.d/zeroclaw 2>/dev/null
    rm -f /opt/etc/init.d/S98cliproxyapi /opt/etc/init.d/S99zeroclaw 2>/dev/null

    debug "Removing old binaries..."
    rm -f /usr/bin/zeroclaw
    rm -f /opt/bin/zeroclaw
    rm -f /opt/cliproxyapi/cli-proxy-api

    force_release_service_runtime 15

    info "Teardown complete -- ready for fresh install"
}

verify_services() {
    ROUTER_IP="$1"
    [ -z "$ROUTER_IP" ] && ROUTER_IP=$(ip addr show br-lan 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
    [ -z "$ROUTER_IP" ] && ROUTER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ROUTER_IP" ] && ROUTER_IP="<device-ip>"

    ZC_COUNT=$(process_count zeroclaw)
    CP_COUNT=$(process_count cli-proxy-api)
    SOCAT_COUNT=$(process_count socat)

    debug "verify_services: zeroclaw=$ZC_COUNT cli-proxy-api=$CP_COUNT socat=$SOCAT_COUNT"

    # Check ports
    PORT_8317=$(port_listener_line 8317)
    PORT_8318=$(port_listener_line 8318)
    PORT_3080=$(port_listener_line 3080)
    debug "port 8317: $PORT_8317"
    debug "port 8318: $PORT_8318"
    debug "port 3080: $PORT_3080"

    echo ""
    echo "======================================================="
    printf "${GREEN} Installation Complete!${NC}\n"
    echo "======================================================="
    echo ""
    echo " Services:"
    echo "   ZeroClaw:    $ZC_COUNT process(es)"
    echo "   CLIProxyAPI: $CP_COUNT process(es)"
    echo "   Socat:       $SOCAT_COUNT process(es)"
    echo ""
    echo " Ports:"
    echo "   8317 (socat): $(echo "$PORT_8317" | grep -q 'NOT' && echo '[FAIL] NOT listening' || echo '[OK] listening')"
    echo "   8318 (api):   $(echo "$PORT_8318" | grep -q 'NOT' && echo '[FAIL] NOT listening' || echo '[OK] listening')"
    echo "   3080 (zc):    $(echo "$PORT_3080" | grep -q 'NOT' && echo '[FAIL] NOT listening' || echo '[OK] listening')"
    echo ""
    echo " Web UI:"
    echo "   ZeroClaw:    http://${ROUTER_IP}:3080"
    echo "   CLIProxy:    http://${ROUTER_IP}:8317/management.html"
    echo ""

    echo " Telegram: Configured"
    echo "   Allowed user: $TELEGRAM_USER_ID"

    echo ""
    echo " Useful commands:"
    if [ "$PLATFORM" = "procd" ]; then
        echo "   /etc/init.d/zeroclaw restart"
        echo "   /etc/init.d/cliproxyapi restart"
        echo "   logread | grep zeroclaw | tail -30"
        echo "   logread | grep cli-proxy | tail -30"
    else
        echo "   /opt/etc/init.d/S99zeroclaw restart"
        echo "   /opt/etc/init.d/S98cliproxyapi restart"
        echo "   cat /opt/var/log/zeroclaw.log"
        echo "   cat /opt/var/log/cliproxyapi.log"
    fi
    echo ""
    echo " Debug log: cat $LOG_FILE"
    echo ""
}

# =======================================================
# Backup (for uninstall)
# =======================================================

backup_configs() {
    BACKUP_DIR="/root/zeroclaw-backup-$(date +%Y%m%d-%H%M%S)"
    info "Backup config tới $BACKUP_DIR ..."
    mkdir -p "$BACKUP_DIR"

    # ZeroClaw config
    [ -f /root/.zeroclaw/config.toml ] && cp /root/.zeroclaw/config.toml "$BACKUP_DIR/" && info "  config.toml"

    # ZeroClaw memory + sessions
    [ -d /root/.zeroclaw/workspace/memory ] && cp -r /root/.zeroclaw/workspace/memory "$BACKUP_DIR/" && info "  workspace/memory/"
    [ -d /root/.zeroclaw/workspace/sessions ] && cp -r /root/.zeroclaw/workspace/sessions "$BACKUP_DIR/" && info "  workspace/sessions/"

    # CLIProxyAPI auth -- check both possible locations
    CLIPROXY_DIR="/opt/cliproxyapi"
    if [ -d "$CLIPROXY_DIR/auth" ]; then
        mkdir -p "$BACKUP_DIR/auth"
        cp "$CLIPROXY_DIR/auth/"*.json "$BACKUP_DIR/auth/" 2>/dev/null
        AUTH_COUNT=$(ls "$BACKUP_DIR/auth/"*.json 2>/dev/null | wc -l)
        info "  auth/ ($AUTH_COUNT credential files)"
    fi

    # CLIProxyAPI config
    [ -f "$CLIPROXY_DIR/config.yaml" ] && cp "$CLIPROXY_DIR/config.yaml" "$BACKUP_DIR/" && info "  config.yaml"

    info "Backup hoàn tất: $BACKUP_DIR"
    echo ""
}
