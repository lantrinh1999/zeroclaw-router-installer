#!/bin/sh
# =======================================================
# ZeroClaw + CLIProxyAPI Installer for Entware/Buildroot
# =======================================================
# For: non-OpenWrt Linux with Entware support
# Requires: Entware (auto-installed if missing), /opt/ mountpoint
# Usage: sh install.sh (run on device)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
. "$ROOT_DIR/common.sh"

header "ZeroClaw + CLIProxyAPI Installer (Entware)"

require_entware_init_scripts() {
    [ -x /opt/etc/init.d/S98cliproxyapi ] || {
        error "ONLY_BINARY requires existing /opt/etc/init.d/S98cliproxyapi"
        return 1
    }
    [ -x /opt/etc/init.d/S99zeroclaw ] || {
        error "ONLY_BINARY requires existing /opt/etc/init.d/S99zeroclaw"
        return 1
    }
}

stop_entware_services_for_only_binary() {
    require_entware_init_scripts || return 1

    step "Stopping services"
    /opt/etc/init.d/S99zeroclaw stop 2>/dev/null || true
    /opt/etc/init.d/S98cliproxyapi stop 2>/dev/null || true
    force_release_service_runtime 10
}

start_entware_services() {
    require_entware_init_scripts || return 1
    MGMT_PORT=$(detect_management_port)

    step "Starting services"
    info "Ensuring clean runtime state before service start..."
    prepare_fresh_service_start 10

    info "Starting CLIProxyAPI..."
    /opt/etc/init.d/S98cliproxyapi start

    if wait_for_port_listening "$MGMT_PORT" 15; then
        info "CLIProxyAPI is running on port $MGMT_PORT"
    else
        show_port_snapshot "$MGMT_PORT" 3080
        warn "CLIProxyAPI may not have started. Check: cat /opt/var/log/cliproxyapi.log"
    fi

    info "Starting ZeroClaw..."
    /opt/etc/init.d/S99zeroclaw start
    sleep 3

    if is_process_running zeroclaw; then
        info "ZeroClaw is running"
    else
        PIDS=$(process_pids zeroclaw)
        [ -n "$PIDS" ] && debug "zeroclaw pid(s): $PIDS" || debug "zeroclaw pid(s): <none>"
        warn "ZeroClaw may not have started. Check: cat /opt/var/log/zeroclaw.log"
    fi
}

# -- Platform detection + confirm --------------------
detect_platform
INSTALLER="entware"  # Force installer strategy for this installer

if [ "$BIN_ARCH" = "unknown" ]; then
    error "Unsupported architecture: $ARCH"
    exit 1
fi

confirm_platform || exit 1

# -- Pre-checks --------------------------------------
BIN_SRC="$ROOT_DIR/binaries/$BIN_ARCH"
CONFIGS="$ROOT_DIR/configs"

check_binaries_exist "$BIN_SRC" || exit 1
check_disk_space 100 || exit 1

if [ "${ONLY_BINARY:-0}" = "1" ]; then
    info "ONLY_BINARY=1 detected; refreshing installed binaries and management UI only"
    run_only_binary_update "$BIN_SRC" "$CONFIGS" /opt/bin/zeroclaw /opt/cliproxyapi/cli-proxy-api /opt/cliproxyapi stop_entware_services_for_only_binary start_entware_services || exit 1
    step "Verification"
    verify_services
    exit 0
fi

# -- Entware check/install --------------------------
if [ "$ENTWARE_INSTALLED" = "0" ]; then
    echo ""
    warn "Entware chưa được cài đặt."
    echo ""
    echo "  Entware là package manager cho embedded Linux."
    echo "  Cài vào /opt/ -- KHÔNG ảnh hưởng hệ thống gốc."
    echo "  Yêu cầu: kernel >= 3.4, /opt/ writeable"
    echo ""

    # Check kernel version
    KVER_MAJOR=$(uname -r | cut -d. -f1)
    KVER_MINOR=$(uname -r | cut -d. -f2)
    if [ "$KVER_MAJOR" -lt 3 ] || { [ "$KVER_MAJOR" -eq 3 ] && [ "$KVER_MINOR" -lt 4 ]; }; then
        error "Kernel $(uname -r) < 3.4 -- Entware không hỗ trợ."
        exit 1
    fi
    info "Kernel $(uname -r) >= 3.4 ✓"

    # Check /opt is writable
    if ! touch /opt/.write_test 2>/dev/null; then
        error "/opt/ không writable. Cần mount storage vào /opt/"
        echo ""
        echo "  Gợi ý: mount USB/SD card vào /opt/"
        echo "    mkdir -p /opt"
        echo "    mount /dev/sdX1 /opt"
        exit 1
    fi
    rm -f /opt/.write_test
    info "/opt/ writable ✓"

    if confirm "Cài đặt Entware?"; then
        info "Downloading Entware installer..."

        # Determine entware architecture
        ENTWARE_ARCH=""
        case "$ARCH" in
            aarch64)
                ENTWARE_ARCH="aarch64-k3.10"
                ;;
            armv7*)
                ENTWARE_ARCH="armv7sf-k3.2"
                ;;
            *)
                error "Không biết Entware arch cho: $ARCH"
                exit 1
                ;;
        esac

        info "Entware architecture: $ENTWARE_ARCH"

        # Download and run installer
        INSTALLER_URL="https://bin.entware.net/$ENTWARE_ARCH/installer/generic.sh"
        if command -v wget >/dev/null 2>&1; then
            wget -qO /tmp/entware-installer.sh "$INSTALLER_URL"
        elif command -v curl >/dev/null 2>&1; then
            curl -fsSL -o /tmp/entware-installer.sh "$INSTALLER_URL"
        else
            error "Cần wget hoặc curl để tải Entware."
            exit 1
        fi

        sh /tmp/entware-installer.sh
        rm -f /tmp/entware-installer.sh

        # Verify installation
        if [ -x /opt/bin/opkg ]; then
            info "Entware installed successfully ✓"
            ENTWARE_OPKG="/opt/bin/opkg"
            ENTWARE_INSTALLED=1
        else
            error "Entware installation failed."
            exit 1
        fi
    else
        error "Entware is required. Installation cancelled."
        exit 1
    fi
fi

info "Entware: installed ✓"

# -- Setup PATH --------------------------------------
# Ensure /opt/bin and /opt/sbin are in PATH
if ! echo "$PATH" | grep -q "/opt/bin"; then
    export PATH="/opt/sbin:/opt/bin:$PATH"
    # Add to profile for persistence
    PROFILE_FILE="/opt/etc/profile"
    if [ -f "$PROFILE_FILE" ] && ! grep -q "zeroclaw" "$PROFILE_FILE" 2>/dev/null; then
        echo "" >> "$PROFILE_FILE"
        echo "# ZeroClaw PATH" >> "$PROFILE_FILE"
        echo 'export PATH="/opt/sbin:/opt/bin:$PATH"' >> "$PROFILE_FILE"
        info "PATH updated in $PROFILE_FILE"
    fi
fi

# -- User input (mandatory Telegram) -----------------
echo ""
step "Telegram config (mandatory)"
ask_telegram_config || exit 1
echo ""

# -- Cleanup existing installation (if reinstalling) --
cleanup_existing_installation

# -- Install binaries --------------------------------
info "Installing binaries..."

install_binary_from_stage "$BIN_SRC/zeroclaw" /opt/bin/zeroclaw "zeroclaw"
chmod +x /opt/bin/zeroclaw
info "  /opt/bin/zeroclaw installed"

mkdir -p /opt/cliproxyapi
install_binary_from_stage "$BIN_SRC/cli-proxy-api" /opt/cliproxyapi/cli-proxy-api "cli-proxy-api"
chmod +x /opt/cliproxyapi/cli-proxy-api
info "  /opt/cliproxyapi/cli-proxy-api installed"

# -- Install configs ---------------------------------
install_zeroclaw_config "$CONFIGS"
install_cliproxy_config "$CONFIGS" "/opt/cliproxyapi"

# -- Install init scripts ---------------------------
info "Installing init scripts (SysV)..."

mkdir -p /opt/etc/init.d

cp "$SCRIPT_DIR/init-scripts/S98cliproxyapi" /opt/etc/init.d/S98cliproxyapi
chmod +x /opt/etc/init.d/S98cliproxyapi

cp "$SCRIPT_DIR/init-scripts/S99zeroclaw" /opt/etc/init.d/S99zeroclaw
chmod +x /opt/etc/init.d/S99zeroclaw

info "  /opt/etc/init.d/S98cliproxyapi"
info "  /opt/etc/init.d/S99zeroclaw"

# -- Inject Telegram config --------------------------
inject_telegram_config

set_zeroclaw_provider_port 8317 || exit 1

# -- Start services ----------------------------------
start_entware_services || exit 1

# -- Encrypt credentials ----------------------------
info "Encrypting sensitive config values..."
/opt/bin/zeroclaw config encrypt --config-dir /root/.zeroclaw 2>/dev/null || true

# -- Summary -----------------------------------------
verify_services

echo ""
info "Done! Send a message to your Telegram bot to test."
