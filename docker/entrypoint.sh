#!/bin/sh
# =======================================================
# ZeroClaw Test Router - Entrypoint (Multi-Device)
# =======================================================
# Đọc device info từ /etc/device/ubus-board.json

# Parse device info
MODEL=$(grep '"model"' /etc/device/ubus-board.json 2>/dev/null | cut -d'"' -f4)
DISTRIB=$(grep DISTRIB_DESCRIPTION /etc/kwrt_release /etc/openwrt_release 2>/dev/null | head -1 | cut -d"'" -f2)
TARGET=$(grep DISTRIB_TARGET /etc/kwrt_release /etc/openwrt_release 2>/dev/null | head -1 | cut -d"'" -f2)

[ -z "$MODEL" ] && MODEL="Unknown Device"
[ -z "$DISTRIB" ] && DISTRIB="Unknown OS"
[ -z "$TARGET" ] && TARGET="unknown"

start_enabled_services() {
    echo ""
    echo "--- Boot-enabled services ---"

    FOUND=0
    for script in /etc/rc.d/S*; do
        [ -e "$script" ] || continue
        FOUND=1
        echo "  [>] $(basename "$script")"
        if "$script" start; then
            echo "  [ok] $(basename "$script")"
        else
            echo "  [!!] $(basename "$script") failed"
        fi
    done

    if [ "$FOUND" = "0" ]; then
        echo "  (no enabled services)"
    fi
}

echo ""
echo "=========================================="
echo " $MODEL"
echo " $DISTRIB"
echo "------------------------------------------"
echo " Arch:    $(uname -m)"
echo " Cores:   $(nproc 2>/dev/null || echo '?')"
echo " RAM:     $(awk '/MemTotal/{printf "%.0fMB", $2/1024}' /proc/meminfo)"
echo " Kernel:  $(uname -r)"
echo " Target:  $TARGET"
echo " Shell:   ash (busybox)"
echo "=========================================="
echo ""

# --- Start procd ---
/usr/sbin/procd &
sleep 0.2
if pidof procd > /dev/null 2>&1; then
    echo "[ok] procd (PID: $(pidof procd))"
else
    echo "[!!] procd NOT detectable"
fi

# --- Start SSH ---
/usr/sbin/sshd -D -e &
SSHD_PID=$!
echo "[ok] sshd  (PID: $SSHD_PID)"

# --- Simulate boot-enabled OpenWrt services ---
start_enabled_services

# --- Tool inventory ---
echo ""
echo "--- Tools ---"
for tool in opkg ubus logread curl wget tar netstat pidof; do
    path=$(which $tool 2>/dev/null)
    [ -n "$path" ] && echo "  [+] $tool" || echo "  [-] $tool"
done

# --- Filesystem ---
echo ""
echo "--- Filesystem ---"
echo "  /etc/rc.common:  $([ -f /etc/rc.common ] && echo 'present' || echo 'missing')"
echo "  /etc/init.d:     $(ls /etc/init.d/ 2>/dev/null | wc -l) scripts"

# --- Connection ---
echo ""
echo "=== ssh -p 2222 root@localhost (password: root) ==="
echo "=== sh setup.sh localhost -p 2222                ==="
echo ""
wait $SSHD_PID
