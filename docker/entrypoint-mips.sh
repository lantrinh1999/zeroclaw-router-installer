#!/bin/sh
# =======================================================
# ZeroClaw Test Router - Entrypoint (MIPS/Buildroot)
# =======================================================
# Entrypoint cho thiết bị Buildroot + Entware (không procd)

# Parse device info
MODEL=$(grep '"model"' /etc/device/ubus-board.json 2>/dev/null | cut -d'"' -f4)
SYSTEM=$(grep '"system"' /etc/device/ubus-board.json 2>/dev/null | cut -d'"' -f4)
DISTRIB=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2)

[ -z "$MODEL" ] && MODEL="Unknown Device"
[ -z "$SYSTEM" ] && SYSTEM="Unknown"
[ -z "$DISTRIB" ] && DISTRIB="Buildroot Linux"

echo ""
echo "=========================================="
echo " $MODEL"
echo " $DISTRIB"
echo "------------------------------------------"
echo " Arch:    $(uname -m)"
echo " System:  $SYSTEM"
echo " Cores:   $(nproc 2>/dev/null || echo '?')"
echo " RAM:     $(awk '/MemTotal/{printf "%.0fMB", $2/1024}' /proc/meminfo)"
echo " Kernel:  $(uname -r)"
echo " Shell:   ash (busybox)"
echo " Init:    SysV (Entware)"
echo "=========================================="
echo ""

# --- NO procd (this is Buildroot, not OpenWrt) ---

# --- Start SSH ---
/usr/sbin/sshd -D -e &
SSHD_PID=$!
echo "[ok] sshd  (PID: $SSHD_PID)"

# --- Tool inventory ---
echo ""
echo "--- Tools ---"
for tool in opkg ubus logread wget tar netstat pidof; do
    path=$(which $tool 2>/dev/null)
    [ -n "$path" ] && echo "  [+] $tool ($path)" || echo "  [-] $tool"
done

# --- Entware layout ---
echo ""
echo "--- Entware ---"
echo "  /opt/bin/opkg:      $([ -x /opt/bin/opkg ] && echo 'present' || echo 'missing')"
echo "  /opt/etc/init.d:    $(ls /opt/etc/init.d/ 2>/dev/null | wc -l) scripts"
echo "  /opt/var/log:       $([ -d /opt/var/log ] && echo 'present' || echo 'missing')"

# --- Filesystem ---
echo ""
echo "--- Filesystem ---"
echo "  /etc/buildroot-release: $([ -f /etc/buildroot-release ] && echo 'present' || echo 'missing')"
echo "  /etc/openwrt_release:   $([ -f /etc/openwrt_release ] && echo 'ABSENT (correct)' || echo 'ABSENT (correct)')"
echo "  /etc/rc.common:         $([ -f /etc/rc.common ] && echo 'present' || echo 'ABSENT (correct)')"
echo "  /etc/init.d:            $(ls /etc/init.d/ 2>/dev/null | wc -l) scripts"

# --- Connection ---
echo ""
echo "=== ssh -p 2223 root@localhost (password: root) ==="
echo "=== sh setup.sh localhost -p 2223                ==="
echo ""
wait $SSHD_PID
