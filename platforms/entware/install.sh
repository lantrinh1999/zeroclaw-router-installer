#!/bin/sh
# =======================================================
# ZeroClaw + CLIProxyAPI Installer for Entware/Buildroot
# =======================================================
# For: MIPS32r2 (Creality K1, etc.) and other non-OpenWrt Linux
# Requires: Entware (auto-installed if missing), /opt/ mountpoint
# Usage: sh install.sh (run on device)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
. "$ROOT_DIR/common.sh"

header "ZeroClaw + CLIProxyAPI Installer (Entware)"

# -- Platform detection + confirm --------------------
detect_platform
PLATFORM="entware"  # Force platform for this installer

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
            mips|mipsel)
                # Check endianness
                if [ "$(echo -n I | od -to2 | head -1 | awk '{print $2}')" = "000111" ]; then
                    ENTWARE_ARCH="mipselsf-k3.4"
                else
                    ENTWARE_ARCH="mipssf-k3.4"
                fi
                ;;
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

mkdir -p /opt/bin
cp "$BIN_SRC/zeroclaw" /opt/bin/zeroclaw
chmod +x /opt/bin/zeroclaw
info "  /opt/bin/zeroclaw installed"

mkdir -p /opt/cliproxyapi
cp "$BIN_SRC/cli-proxy-api" /opt/cliproxyapi/cli-proxy-api
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

# -- Install socat -----------------------------------
info "Installing socat via Entware..."
$ENTWARE_OPKG update >/dev/null 2>&1 || true
$ENTWARE_OPKG install socat 2>/dev/null || warn "socat install failed -- IPv4 access may not work"

# -- Start services ----------------------------------
info "Starting CLIProxyAPI..."
/opt/etc/init.d/S98cliproxyapi start

if wait_for_port_listening 8317 15; then
    info "CLIProxyAPI is running (socat:8317 -> api:8318)"
else
    show_port_snapshot 8317 8318
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

# -- Encrypt credentials ----------------------------
info "Encrypting sensitive config values..."
/opt/bin/zeroclaw config encrypt --config-dir /root/.zeroclaw 2>/dev/null || true

# -- Summary -----------------------------------------
verify_services

echo ""
info "Done! Send a message to your Telegram bot to test."
