---
name: openwrt-config-backup-restore
description: Backup và restore config OpenWrt (UCI + ZeroClaw)
version: 1.0.0
---

# OpenWrt Config Backup/Restore

## Backup
```bash
BACKUP_DIR="/root/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
sysupgrade -l > "$BACKUP_DIR/file-list.txt"
cp /root/.zeroclaw/config.toml "$BACKUP_DIR/zeroclaw-config.toml"
cp -r /root/.zeroclaw/workspace/*.md "$BACKUP_DIR/"
uci export > "$BACKUP_DIR/uci-export.txt"
echo "Backup saved to $BACKUP_DIR"
ls -la "$BACKUP_DIR"
```

## Restore
```bash
# Restore ZeroClaw config
cp "$BACKUP_DIR/zeroclaw-config.toml" /root/.zeroclaw/config.toml
/etc/init.d/zeroclaw stop; /etc/init.d/zeroclaw start
```

Tiếng Việt.
