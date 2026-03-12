#!/bin/sh
# =======================================================
# Quick Uninstall -- chạy từ máy tính
# =======================================================
# Usage: sh teardown.sh [device-ip] [-p port]
# Example: sh teardown.sh 192.168.81.1
#          sh teardown.sh localhost -p 2222

# Parse arguments: teardown.sh [ip] [-p port]
ROUTER_IP="192.168.81.1"
SSH_PORT="22"
while [ $# -gt 0 ]; do
    case "$1" in
        -p) SSH_PORT="$2"; shift 2 ;;
        *)  ROUTER_IP="$1"; shift ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REMOTE_DIR="/tmp/zeroclaw-uninstaller"

SOCK="/tmp/.zc-ssh-$$"
SSH_OPTS="-p $SSH_PORT -o StrictHostKeyChecking=no -o ControlMaster=auto -o ControlPath=$SOCK -o ControlPersist=120"
SCP_OPTS="-P $SSH_PORT -O"

cleanup() { ssh -o ControlPath="$SOCK" -O exit "root@$ROUTER_IP" 2>/dev/null; rm -f "$SOCK"; }
trap cleanup EXIT INT TERM

parse_detect_var() {
    printf '%s\n' "$DETECT" | sed -n "s/^$1=//p" | head -n 1
}

echo ""
echo "======================================================="
echo " ZeroClaw Uninstaller -> $ROUTER_IP (port $SSH_PORT)"
echo "======================================================="
echo ""
echo "[0/3] Connecting (nhập password 1 lần)..."
ssh $SSH_OPTS "root@$ROUTER_IP" "echo ok" >/dev/null || { echo "[ERROR] SSH failed"; exit 1; }
echo "[OK] Connected"
echo ""

# Step 1: Detect platform
echo "[1/3] Detecting platform..."
ssh $SSH_OPTS "root@$ROUTER_IP" "rm -rf '$REMOTE_DIR'; mkdir -p '$REMOTE_DIR'" >/dev/null || { echo "[ERROR] Cannot prepare remote staging"; exit 1; }
tar cf - -C "$SCRIPT_DIR" common.sh \
    | ssh $SSH_OPTS "root@$ROUTER_IP" "tar xf - -C '$REMOTE_DIR'" \
    || { echo "[ERROR] Cannot upload detector"; exit 1; }

DETECT=$(ssh $SSH_OPTS "root@$ROUTER_IP" "cd '$REMOTE_DIR' && . ./common.sh >/dev/null 2>&1 && detect_platform >/dev/null 2>&1 && print_platform_exports")

INSTALLER=$(parse_detect_var INSTALLER)
BIN_ARCH=$(parse_detect_var BIN_ARCH)
ARCH=$(parse_detect_var ARCH)
INIT_TYPE=$(parse_detect_var INIT_TYPE)
EXEC_MODE=$(parse_detect_var EXEC_MODE)

echo "  Installer: $INSTALLER ($ARCH, init=$INIT_TYPE, mode=$EXEC_MODE)"

if [ "$INSTALLER" = "unknown" ]; then
    echo "[ERROR] Cannot detect installer"
    exit 1
fi

# Step 2: Upload uninstaller
echo ""
echo "[2/3] Uploading uninstaller..."
ssh $SSH_OPTS "root@$ROUTER_IP" "rm -rf $REMOTE_DIR; mkdir -p $REMOTE_DIR/installers/$INSTALLER"

# Try scp first, fallback to tar-over-ssh if device doesn't have scp
HAS_SCP=$(ssh $SSH_OPTS "root@$ROUTER_IP" "command -v scp >/dev/null 2>&1 && echo yes || echo no")

if [ "$HAS_SCP" = "yes" ]; then
    echo "  Using scp..."
    scp $SCP_OPTS -o ControlPath="$SOCK" \
        "$SCRIPT_DIR/common.sh" \
        "root@$ROUTER_IP:$REMOTE_DIR/" \
        && scp $SCP_OPTS -o ControlPath="$SOCK" \
        "$SCRIPT_DIR/installers/$INSTALLER/uninstall.sh" \
        "root@$ROUTER_IP:$REMOTE_DIR/installers/$INSTALLER/" \
        || { echo "[ERROR] Upload failed"; exit 1; }
else
    echo "  scp not found on device, using tar over ssh..."
    tar cf - -C "$SCRIPT_DIR" \
        "common.sh" \
        "installers/$INSTALLER/uninstall.sh" \
        | ssh $SSH_OPTS "root@$ROUTER_IP" "tar xf - -C $REMOTE_DIR" \
        || { echo "[ERROR] Upload failed"; exit 1; }
fi
echo "[OK] Uploaded"

# Step 3: Run uninstaller
echo ""
echo "[3/3] Running uninstaller (installer: $INSTALLER)..."
echo "-------------------------------------"
ssh $SSH_OPTS "root@$ROUTER_IP" "cd $REMOTE_DIR && sh installers/$INSTALLER/uninstall.sh"
echo "-------------------------------------"
echo ""
