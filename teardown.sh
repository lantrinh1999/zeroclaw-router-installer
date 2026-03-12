#!/bin/sh
# =======================================================
# Quick Uninstall -- chạy từ máy tính
# =======================================================
# Usage: sh teardown.sh [device-ip]
# Example: sh teardown.sh 192.168.81.1

ROUTER_IP="${1:-192.168.81.1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REMOTE_DIR="/tmp/zeroclaw-uninstaller"

SOCK="/tmp/.zc-ssh-$$"
SSH_OPTS="-o StrictHostKeyChecking=no -o ControlMaster=auto -o ControlPath=$SOCK -o ControlPersist=120"

cleanup() { ssh -o ControlPath="$SOCK" -O exit "root@$ROUTER_IP" 2>/dev/null; rm -f "$SOCK"; }
trap cleanup EXIT INT TERM

echo ""
echo "======================================================="
echo " ZeroClaw Uninstaller -> $ROUTER_IP"
echo "======================================================="
echo ""
echo "[0/3] Connecting (nhập password 1 lần)..."
ssh $SSH_OPTS "root@$ROUTER_IP" "echo ok" >/dev/null || { echo "[ERROR] SSH failed"; exit 1; }
echo "[OK] Connected"
echo ""

# Step 1: Detect platform
echo "[1/3] Detecting platform..."
DETECT=$(ssh $SSH_OPTS "root@$ROUTER_IP" '
ARCH=$(uname -m)
case "$ARCH" in
    aarch64)     BIN_ARCH="aarch64" ;;
    mips|mipsel) BIN_ARCH="mips32r2" ;;
    *)           BIN_ARCH="unknown" ;;
esac

if pidof procd >/dev/null 2>&1 && [ -d /etc/init.d ] && [ -d /etc/config ]; then
    PLATFORM="procd"
elif [ -x /opt/bin/opkg ] || [ -d /opt/etc/init.d ]; then
    PLATFORM="entware"
else
    PLATFORM="unknown"
fi

echo "PLATFORM=$PLATFORM"
echo "BIN_ARCH=$BIN_ARCH"
echo "ARCH=$ARCH"
')

PLATFORM=$(echo "$DETECT" | grep "^PLATFORM=" | cut -d= -f2)
BIN_ARCH=$(echo "$DETECT" | grep "^BIN_ARCH=" | cut -d= -f2)
ARCH=$(echo "$DETECT" | grep "^ARCH=" | cut -d= -f2)

echo "  Platform: $PLATFORM ($ARCH)"

if [ "$PLATFORM" = "unknown" ]; then
    echo "[ERROR] Cannot detect platform"
    exit 1
fi

# Step 2: Upload uninstaller
echo ""
echo "[2/3] Uploading uninstaller..."
ssh $SSH_OPTS "root@$ROUTER_IP" "rm -rf $REMOTE_DIR; mkdir -p $REMOTE_DIR/platforms/$PLATFORM"
scp -O $SSH_OPTS \
    "$SCRIPT_DIR/common.sh" \
    "root@$ROUTER_IP:$REMOTE_DIR/" || { echo "[ERROR] Upload failed"; exit 1; }
scp -O $SSH_OPTS -r \
    "$SCRIPT_DIR/platforms/$PLATFORM/uninstall.sh" \
    "root@$ROUTER_IP:$REMOTE_DIR/platforms/$PLATFORM/" || { echo "[ERROR] Upload failed"; exit 1; }
echo "[OK] Uploaded"

# Step 3: Run uninstaller
echo ""
echo "[3/3] Running uninstaller (platform: $PLATFORM)..."
echo "-------------------------------------"
ssh $SSH_OPTS "root@$ROUTER_IP" "cd $REMOTE_DIR && sh platforms/$PLATFORM/uninstall.sh"
echo "-------------------------------------"
echo ""
