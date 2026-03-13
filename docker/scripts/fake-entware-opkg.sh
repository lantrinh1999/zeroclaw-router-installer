#!/bin/sh
# Fake Entware opkg for Docker testing
# Simulates /opt/bin/opkg behavior

case "$1" in
    update)
        echo "Downloading http://bin.entware.net/aarch64-k3.10/Packages.gz"
        echo "Updated list of available packages in /opt/var/opkg-lists/entware"
        ;;
    install)
        shift
        for pkg in "$@"; do
            echo "Installing package $pkg (0.1-1) to root..."
            echo "Configuring $pkg."
        done
        ;;
    list-installed)
        echo "busybox - 1.36.1-1"
        echo "libc - 2.27-3"
        echo "libgcc - 8.4.0-3"
        echo "libpthread - 2.27-3"
        echo "librt - 2.27-3"
        ;;
    list)
        echo "curl - 8.5.0-1 - Client URL library"
        echo "busybox - 1.36.1-1 - BusyBox"
        ;;
    --version|-V)
        echo "opkg version 2022-02-24 (Entware)"
        ;;
    *)
        echo "usage: opkg [options...] sub-command [arguments...]"
        echo "  update                  Update list of available packages"
        echo "  install <pkgs>          Install package(s)"
        echo "  list                    List available packages"
        echo "  list-installed          List installed packages"
        ;;
esac
exit 0
