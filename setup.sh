#!/bin/sh
# Quick Setup -- chay tu may tinh, tu dong upload + cai
# Usage: sh setup.sh [device-ip] [-p port]
# Example: sh setup.sh 192.168.81.1
#          sh setup.sh localhost -p 2222
# Supports: aarch64/OpenWrt, MIPS32r2/Entware

# Parse arguments: setup.sh [ip] [-p port]
ROUTER_IP="192.168.81.1"
SSH_PORT="22"
while [ $# -gt 0 ]; do
    case "$1" in
        -p) SSH_PORT="$2"; shift 2 ;;
        *)  ROUTER_IP="$1"; shift ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REMOTE_DIR="/tmp/zeroclaw-router-installer"

# SSH multiplexing -- nhập password 1 lần, dùng lại cho mọi bước
SOCK="/tmp/.zc-ssh-$$"
SSH_OPTS="-p $SSH_PORT -o StrictHostKeyChecking=no -o ControlMaster=auto -o ControlPath=$SOCK -o ControlPersist=120"
SCP_OPTS="-P $SSH_PORT -O"

cleanup() { ssh -o ControlPath="$SOCK" -O exit "root@$ROUTER_IP" 2>/dev/null; rm -f "$SOCK"; }
trap cleanup EXIT INT TERM

parse_detect_var() {
    printf '%s\n' "$DETECT" | sed -n "s/^$1=//p" | head -n 1
}

echo ""
echo "ZeroClaw Quick Setup -> $ROUTER_IP (port $SSH_PORT)"
echo ""
echo "[0/5] Connecting (nhập password 1 lần)..."
ssh $SSH_OPTS "root@$ROUTER_IP" "echo ok" >/dev/null || { echo "[ERROR] SSH failed"; exit 1; }
echo "[OK] Connected"
echo ""

# -----------------------------------------------------
# Step 1: Platform detection (remote)
# -----------------------------------------------------
echo "[1/5] Detecting platform..."
ssh $SSH_OPTS "root@$ROUTER_IP" "rm -rf '$REMOTE_DIR'; mkdir -p '$REMOTE_DIR'" >/dev/null || { echo "[ERROR] Cannot prepare remote staging"; exit 1; }
tar cf - -C "$SCRIPT_DIR" common.sh \
    | ssh $SSH_OPTS "root@$ROUTER_IP" "tar xf - -C '$REMOTE_DIR'" \
    || { echo "[ERROR] Cannot upload detector"; exit 1; }

DETECT=$(ssh $SSH_OPTS "root@$ROUTER_IP" "cd '$REMOTE_DIR' && . ./common.sh >/dev/null 2>&1 && detect_platform >/dev/null 2>&1 && print_platform_exports")

# Parse results
ARCH=$(parse_detect_var ARCH)
BIN_ARCH=$(parse_detect_var BIN_ARCH)
OS_TYPE=$(parse_detect_var OS_TYPE)
OS_NAME=$(parse_detect_var OS_NAME)
KERNEL=$(parse_detect_var KERNEL)
PID1_COMM=$(parse_detect_var PID1_COMM)
INIT_TYPE=$(parse_detect_var INIT_TYPE)
SERVICE_BACKEND=$(parse_detect_var SERVICE_BACKEND)
INSTALL_LAYOUT=$(parse_detect_var INSTALL_LAYOUT)
INSTALL_BIN_DIR=$(parse_detect_var INSTALL_BIN_DIR)
INSTALL_CLIPROXY_DIR=$(parse_detect_var INSTALL_CLIPROXY_DIR)
EXEC_MODE=$(parse_detect_var EXEC_MODE)
ENTWARE=$(parse_detect_var ENTWARE)
PLATFORM=$(parse_detect_var PLATFORM)
RAM=$(parse_detect_var RAM)
DISK=$(parse_detect_var DISK)
RESULT=$(parse_detect_var RESULT)

echo ""
echo "--- Platform Detection ---"
echo "  Architecture:    $ARCH ($BIN_ARCH)"
echo "  OS:              $OS_NAME"
echo "  OS Type:         $OS_TYPE"
echo "  Kernel:          $KERNEL"
echo "  PID 1:           $PID1_COMM"
echo "  Init System:     $INIT_TYPE"
echo "  Backend:         $SERVICE_BACKEND"
echo "  Install Layout:  $INSTALL_LAYOUT"
echo "  Install Bin:     $INSTALL_BIN_DIR"
echo "  CLIProxy Dir:    $INSTALL_CLIPROXY_DIR"
echo "  Execution Mode:  $EXEC_MODE"
echo "  Entware:         $ENTWARE"
echo "  RAM:             $RAM"
echo "  Disk Free:       $DISK"
echo "  Platform:        $PLATFORM"
echo ""

# Show errors
FAILS=$(printf '%s\n' "$DETECT" | grep "^FAIL" || true)
if [ -n "$FAILS" ]; then
    echo "$FAILS" | while read line; do
        echo "  [FAIL] $line"
    done
fi

if [ "$RESULT" = "FAIL" ]; then
    echo ""
    echo "[ERROR] Device not compatible. Cannot install."
    exit 1
fi

if [ "$PLATFORM" = "manual" ]; then
    echo "[WARN] Falling back to manual mode."
    echo "  Services will be installed with start/stop scripts only."
    echo "  Auto-start integration is not enabled in this mode."
    echo ""
fi

# Double-check: user confirms platform detection
printf "  Thông tin trên có chính xác không? Tiếp tục cài đặt? [Y/n]: "
read CONT
if [ "$CONT" = "n" ] || [ "$CONT" = "N" ]; then
    echo "[ABORT] Installation cancelled."
    exit 0
fi
echo "[OK] Platform: $PLATFORM ($BIN_ARCH)"
echo ""

# Check binaries exist locally
if [ ! -f "$SCRIPT_DIR/binaries/$BIN_ARCH/zeroclaw" ] || [ ! -f "$SCRIPT_DIR/binaries/$BIN_ARCH/cli-proxy-api" ]; then
    echo "[ERROR] Missing binaries for $BIN_ARCH"
    echo "  Expected: binaries/$BIN_ARCH/zeroclaw"
    echo "  Expected: binaries/$BIN_ARCH/cli-proxy-api"
    exit 1
fi

# -----------------------------------------------------
# Telegram Config (mandatory -- test before upload)
# -----------------------------------------------------
echo ""
echo "[INFO] Telegram Bot Token va User ID la bat buoc."
echo "  ZeroClaw can Telegram de gui thong bao va nhan lenh."
echo ""

while true; do
    printf "  Telegram Bot Token: "
    read TELEGRAM_BOT_TOKEN
    if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
        echo "  [WARN] Bot Token la bat buoc. Vui long nhap lai."
        continue
    fi

    printf "  Telegram User ID (numeric): "
    read TELEGRAM_USER_ID
    if [ -z "$TELEGRAM_USER_ID" ]; then
        echo "  [WARN] User ID la bat buoc. Vui long nhap lai."
        continue
    fi

    # Test Telegram API from local machine (curl first, wget fallback)
    echo "  [INFO] Dang gui tin nhan test qua Telegram..."
    TG_URL="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
    TG_MSG="ZeroClaw installer: Ket noi Telegram thanh cong."

    TG_RESULT=""
    if command -v curl >/dev/null 2>&1; then
        TG_RESULT=$(curl -s --connect-timeout 10 --max-time 15 -X POST "$TG_URL" -d "chat_id=${TELEGRAM_USER_ID}&text=${TG_MSG}" 2>&1)
    elif command -v wget >/dev/null 2>&1; then
        TG_RESULT=$(wget -qO- -T 15 -t 1 --post-data="chat_id=${TELEGRAM_USER_ID}&text=${TG_MSG}" "$TG_URL" 2>&1)
    else
        echo "  [ERROR] Can curl hoac wget de test Telegram."
        exit 1
    fi

    if echo "$TG_RESULT" | grep -q '"ok":true'; then
        echo "  [OK] Telegram test thanh cong!"
        printf "  Ban da nhan duoc tin nhan test? [Y/n]: "
        read TG_CONFIRM
        if [ "$TG_CONFIRM" = "n" ] || [ "$TG_CONFIRM" = "N" ]; then
            echo "  [WARN] Vui long kiem tra lai Bot Token va User ID."
            continue
        fi
        break
    else
        TG_ERR=$(echo "$TG_RESULT" | grep -o '"description":"[^"]*"' | cut -d'"' -f4)
        [ -z "$TG_ERR" ] && TG_ERR="Unknown error"
        echo "  [WARN] Telegram test that bai: $TG_ERR"
        printf "  Tiep tuc cai dat voi thong tin nay? [Y/n]: "
        read TG_SKIP
        if [ "$TG_SKIP" = "n" ] || [ "$TG_SKIP" = "N" ]; then
            echo "  [INFO] Nhap lai thong tin Telegram..."
            continue
        fi
        echo "  [INFO] Tiep tuc cai dat -- se inject Telegram config vao file."
        break
    fi
done
echo ""

# -----------------------------------------------------
# Step 2: Upload (tar over SSH -- no scp needed on device)
# -----------------------------------------------------
echo "[2/5] Uploading to device..."
ssh $SSH_OPTS "root@$ROUTER_IP" "rm -rf $REMOTE_DIR; mkdir -p $REMOTE_DIR"

# Pack locally, pipe over SSH, extract on device
# This works on any system without needing scp/sftp on the remote
tar cf - -C "$SCRIPT_DIR" \
    "binaries/$BIN_ARCH" \
    "configs" \
    "platforms/$PLATFORM" \
    "common.sh" \
    | ssh $SSH_OPTS "root@$ROUTER_IP" "tar xf - -C $REMOTE_DIR" \
    || { echo "[ERROR] Upload failed"; exit 1; }

echo "[OK] Upload complete"

# -----------------------------------------------------
# Step 3: Install
# -----------------------------------------------------
echo ""
echo "[3/5] Running installer (platform: $PLATFORM)..."
echo "-------------------------------------"
# CRITICAL: < /dev/null prevents SSH from consuming stdin
# which would cause 'read' calls in install.sh to fail with set -e
ssh $SSH_OPTS "root@$ROUTER_IP" \
    "cd $REMOTE_DIR && SKIP_CONFIRM=1 TELEGRAM_BOT_TOKEN='$TELEGRAM_BOT_TOKEN' TELEGRAM_USER_ID='$TELEGRAM_USER_ID' sh platforms/$PLATFORM/install.sh" \
    < /dev/null
INSTALL_RC=$?
echo "-------------------------------------"

if [ "$INSTALL_RC" != "0" ]; then
    echo "[ERROR] Installer exited with code $INSTALL_RC"
    echo "[INFO] Fetching install log from device..."
    echo ""
    ssh $SSH_OPTS "root@$ROUTER_IP" "cat /tmp/zeroclaw-install.log 2>/dev/null" < /dev/null || true
    echo ""
    echo "[ERROR] Installation failed. Check the log above for details."
    exit 1
fi

# -----------------------------------------------------
# Step 4: Verify
# -----------------------------------------------------
echo ""
echo "[4/5] Verifying..."
sleep 3

# Check HTTP access
MGMT_PORT=""
HTTP_CODE=""
for CANDIDATE_PORT in 8317 8318; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://$ROUTER_IP:$CANDIDATE_PORT/management.html" 2>/dev/null)
    if [ "$HTTP_CODE" = "200" ]; then
        MGMT_PORT="$CANDIDATE_PORT"
        break
    fi
done

if [ -n "$MGMT_PORT" ]; then
    echo "[OK] Management UI: http://$ROUTER_IP:$MGMT_PORT/management.html"
else
    echo "[WARN] Management UI returned HTTP ${HTTP_CODE:-000}"
    echo "[INFO] Fetching install log for diagnostics..."
    ssh $SSH_OPTS "root@$ROUTER_IP" "cat /tmp/zeroclaw-install.log 2>/dev/null" < /dev/null || true
fi

# Also save install log locally for reference
LOCAL_LOG="$SCRIPT_DIR/last-install.log"
ssh $SSH_OPTS "root@$ROUTER_IP" "cat /tmp/zeroclaw-install.log 2>/dev/null" < /dev/null > "$LOCAL_LOG" 2>/dev/null || true
[ -s "$LOCAL_LOG" ] && echo "[OK] Install log saved to: $LOCAL_LOG"

# -----------------------------------------------------
# Step 5: Cleanup staging files
# -----------------------------------------------------
echo ""
echo "[5/5] Cleaning staging files..."
ssh $SSH_OPTS "root@$ROUTER_IP" "rm -rf $REMOTE_DIR" < /dev/null \
    && echo "[OK] Removed remote staging directory: $REMOTE_DIR" \
    || echo "[WARN] Could not remove remote staging directory: $REMOTE_DIR"

# -----------------------------------------------------
# Done
# -----------------------------------------------------
[ -z "$MGMT_PORT" ] && MGMT_PORT="8317"
echo ""
echo "Done! Open http://$ROUTER_IP:$MGMT_PORT/management.html"
echo "  Platform: $PLATFORM ($BIN_ARCH)"
echo "  Install log (device): /tmp/zeroclaw-install.log"
echo "  Install log (local):  $LOCAL_LOG"
echo ""
