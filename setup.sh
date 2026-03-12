#!/bin/sh
# Quick Setup -- chay tu may tinh, tu dong upload + cai
# Usage: sh setup.sh [device-ip]
# Example: sh setup.sh 192.168.81.1
# Supports: aarch64/OpenWrt, MIPS32r2/Entware

ROUTER_IP="${1:-192.168.81.1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REMOTE_DIR="/tmp/zeroclaw-router-installer"

# SSH multiplexing -- nhập password 1 lần, dùng lại cho mọi bước
SOCK="/tmp/.zc-ssh-$$"
SSH_OPTS="-o StrictHostKeyChecking=no -o ControlMaster=auto -o ControlPath=$SOCK -o ControlPersist=120"

cleanup() { ssh -o ControlPath="$SOCK" -O exit "root@$ROUTER_IP" 2>/dev/null; rm -f "$SOCK"; }
trap cleanup EXIT INT TERM

echo ""
echo "ZeroClaw Quick Setup -> $ROUTER_IP"
echo ""
echo "[0/5] Connecting (nhập password 1 lần)..."
ssh $SSH_OPTS "root@$ROUTER_IP" "echo ok" >/dev/null || { echo "[ERROR] SSH failed"; exit 1; }
echo "[OK] Connected"
echo ""

# -----------------------------------------------------
# Step 1: Platform detection (remote)
# -----------------------------------------------------
echo "[1/5] Detecting platform..."
DETECT=$(ssh $SSH_OPTS "root@$ROUTER_IP" '
ARCH=$(uname -m)
KERNEL=$(uname -r)

# Detect OS type (structure-based: procd + init.d + config = OpenWrt-family)
if pidof procd >/dev/null 2>&1 && [ -d /etc/init.d ] && [ -d /etc/config ]; then
    OS_TYPE="openwrt"
    if [ -f /etc/openwrt_release ]; then
        OS_NAME=$(grep DISTRIB_DESCRIPTION /etc/openwrt_release 2>/dev/null | cut -d"'"'"'" -f2)
    elif [ -f /etc/kwrt_release ]; then
        OS_NAME=$(grep DISTRIB_DESCRIPTION /etc/kwrt_release 2>/dev/null | cut -d"'"'"'" -f2)
    fi
    [ -z "$OS_NAME" ] && OS_NAME=$(cat /etc/os-release 2>/dev/null | grep "^PRETTY_NAME=" | cut -d"\"" -f2)
    [ -z "$OS_NAME" ] && OS_NAME="OpenWrt-based (custom)"
elif [ -f /etc/buildroot-release ] || [ -d /usr/share/buildroot ]; then
    OS_TYPE="buildroot"
    OS_NAME="Buildroot Linux"
else
    OS_TYPE="linux"
    OS_NAME=$(cat /etc/os-release 2>/dev/null | grep "^PRETTY_NAME=" | cut -d"\"" -f2)
    [ -z "$OS_NAME" ] && OS_NAME="Linux (unknown)"
fi

# Detect binary arch
case "$ARCH" in
    aarch64)     BIN_ARCH="aarch64" ;;
    mips|mipsel) BIN_ARCH="mips32r2" ;;
    *)           BIN_ARCH="unknown" ;;
esac

# Detect init system + entware
INIT_TYPE="unknown"
if pidof procd >/dev/null 2>&1; then
    INIT_TYPE="procd"
elif [ -d /opt/etc/init.d ]; then
    INIT_TYPE="sysv-entware"
elif [ -d /etc/init.d ]; then
    INIT_TYPE="sysv"
fi

ENTWARE=$([ -x /opt/bin/opkg ] && echo "yes" || echo "no")

# Determine platform
PLATFORM="unknown"
if [ "$OS_TYPE" = "openwrt" ]; then
    PLATFORM="procd"
elif [ "$ENTWARE" = "yes" ] || [ "$OS_TYPE" = "buildroot" ] || [ "$OS_TYPE" = "linux" ]; then
    PLATFORM="entware"
fi

# Get system info
RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk "{print \$2}" || echo "0")
RAM_MB=$((RAM_KB / 1024))

if [ "$PLATFORM" = "procd" ]; then
    DISK_KB=$(df /overlay 2>/dev/null | tail -1 | awk "{print \$4}" || echo "0")
elif [ -d /opt ]; then
    DISK_KB=$(df /opt 2>/dev/null | tail -1 | awk "{print \$4}" || echo "0")
else
    DISK_KB=$(df / 2>/dev/null | tail -1 | awk "{print \$4}" || echo "0")
fi
DISK_MB=$((DISK_KB / 1024))

echo "ARCH=$ARCH"
echo "BIN_ARCH=$BIN_ARCH"
echo "OS_TYPE=$OS_TYPE"
echo "OS_NAME=$OS_NAME"
echo "KERNEL=$KERNEL"
echo "INIT_TYPE=$INIT_TYPE"
echo "ENTWARE=$ENTWARE"
echo "PLATFORM=$PLATFORM"
echo "RAM=${RAM_MB}MB"
echo "DISK=${DISK_MB}MB"

# Validate
ERRORS=""
if [ "$BIN_ARCH" = "unknown" ]; then
    ERRORS="${ERRORS}FAIL arch=$ARCH (unsupported)\n"
fi
if [ "$RAM_MB" -lt 256 ]; then
    ERRORS="${ERRORS}FAIL ram=${RAM_MB}MB (minimum 256MB)\n"
fi
if [ "$DISK_MB" -lt 100 ]; then
    ERRORS="${ERRORS}FAIL disk=${DISK_MB}MB free (minimum 100MB)\n"
fi
if [ "$PLATFORM" = "unknown" ]; then
    ERRORS="${ERRORS}FAIL platform=unknown\n"
fi

if [ -n "$ERRORS" ]; then
    printf "$ERRORS"
    echo "RESULT=FAIL"
else
    echo "RESULT=OK"
fi
')

# Parse results
ARCH=$(echo "$DETECT" | grep "^ARCH=" | cut -d= -f2)
BIN_ARCH=$(echo "$DETECT" | grep "^BIN_ARCH=" | cut -d= -f2)
OS_TYPE=$(echo "$DETECT" | grep "^OS_TYPE=" | cut -d= -f2)
OS_NAME=$(echo "$DETECT" | grep "^OS_NAME=" | cut -d= -f2)
KERNEL=$(echo "$DETECT" | grep "^KERNEL=" | cut -d= -f2)
INIT_TYPE=$(echo "$DETECT" | grep "^INIT_TYPE=" | cut -d= -f2)
ENTWARE=$(echo "$DETECT" | grep "^ENTWARE=" | cut -d= -f2)
PLATFORM=$(echo "$DETECT" | grep "^PLATFORM=" | cut -d= -f2)
RAM=$(echo "$DETECT" | grep "^RAM=" | cut -d= -f2)
DISK=$(echo "$DETECT" | grep "^DISK=" | cut -d= -f2)
RESULT=$(echo "$DETECT" | grep "^RESULT=" | cut -d= -f2)

echo ""
echo "--- Platform Detection ---"
echo "  Architecture:  $ARCH ($BIN_ARCH)"
echo "  OS:            $OS_NAME"
echo "  OS Type:       $OS_TYPE"
echo "  Kernel:        $KERNEL"
echo "  Init System:   $INIT_TYPE"
echo "  Entware:       $ENTWARE"
echo "  RAM:           $RAM"
echo "  Disk Free:     $DISK"
echo "  Platform:      $PLATFORM"
echo ""

# Show errors
FAILS=$(echo "$DETECT" | grep "^FAIL" || true)
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
        TG_RESULT=$(curl -s --connect-timeout 10 --max-time 3 -X POST "$TG_URL" -d "chat_id=${TELEGRAM_USER_ID}&text=${TG_MSG}" 2>&1)
    elif command -v wget >/dev/null 2>&1; then
        TG_RESULT=$(wget -qO- --timeout=15 --post-data="chat_id=${TELEGRAM_USER_ID}&text=${TG_MSG}" "$TG_URL" 2>&1)
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
# Step 2: Upload
# -----------------------------------------------------
echo "[2/5] Uploading to device..."
ssh $SSH_OPTS "root@$ROUTER_IP" "rm -rf $REMOTE_DIR; mkdir -p $REMOTE_DIR"
scp -O $SSH_OPTS -r \
    "$SCRIPT_DIR/binaries/$BIN_ARCH" \
    "$SCRIPT_DIR/configs" \
    "$SCRIPT_DIR/platforms/$PLATFORM" \
    "$SCRIPT_DIR/common.sh" \
    "root@$ROUTER_IP:$REMOTE_DIR/" || { echo "[ERROR] Upload failed"; exit 1; }

# Restructure on remote to match expected layout
ssh $SSH_OPTS "root@$ROUTER_IP" "
    mkdir -p $REMOTE_DIR/binaries/$BIN_ARCH
    mv $REMOTE_DIR/$BIN_ARCH/* $REMOTE_DIR/binaries/$BIN_ARCH/
    rmdir $REMOTE_DIR/$BIN_ARCH
    mkdir -p $REMOTE_DIR/platforms/$PLATFORM
    mv $REMOTE_DIR/$PLATFORM/* $REMOTE_DIR/platforms/$PLATFORM/
    rmdir $REMOTE_DIR/$PLATFORM
"
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
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://$ROUTER_IP:8317/management.html" 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    echo "[OK] Management UI: http://$ROUTER_IP:8317/management.html"
else
    echo "[WARN] Management UI returned HTTP $HTTP_CODE"
    echo "[INFO] Fetching install log for diagnostics..."
    ssh $SSH_OPTS "root@$ROUTER_IP" "cat /tmp/zeroclaw-install.log 2>/dev/null" < /dev/null || true
fi

# Also save install log locally for reference
LOCAL_LOG="$SCRIPT_DIR/last-install.log"
ssh $SSH_OPTS "root@$ROUTER_IP" "cat /tmp/zeroclaw-install.log 2>/dev/null" < /dev/null > "$LOCAL_LOG" 2>/dev/null || true
[ -s "$LOCAL_LOG" ] && echo "[OK] Install log saved to: $LOCAL_LOG"

# -----------------------------------------------------
# Step 5: Done
# -----------------------------------------------------
echo ""
echo "Done! Open http://$ROUTER_IP:8317/management.html"
echo "  Platform: $PLATFORM ($BIN_ARCH)"
echo "  Install log (device): /tmp/zeroclaw-install.log"
echo "  Install log (local):  $LOCAL_LOG"
echo ""
