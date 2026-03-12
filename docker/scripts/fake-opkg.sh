#!/bin/sh
# Fake opkg package manager
# Giả lập opkg update/install (không thực sự cài gì)
case "$1" in
  update)
    echo "Downloading http://downloads.openwrt.org/packages/aarch64_cortex-a53/..."
    echo "Updated list of available packages in /var/opkg-lists/."
    ;;
  install)
    shift
    for pkg in "$@"; do
      echo "Installing $pkg (fake) on root..."
      echo "Configuring $pkg."
    done
    ;;
  remove)
    shift
    for pkg in "$@"; do
      echo "Removing package $pkg from root..."
    done
    ;;
  list-installed)
    echo "busybox - 1.36.1-r0"
    echo "openssh-server - 9.6_p1-r0"
    ;;
  *)
    echo "Usage: opkg update|install|remove|list-installed"
    ;;
esac
exit 0
