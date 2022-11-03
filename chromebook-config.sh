#!/usr/bin/env bash
# chromebook-config.sh - Configuration file for chromebook-setup

TOOLCHAIN_VERSION="10.3-2021.07"

# default rootfs and toolchain (arm)
TOOLCHAIN="gcc-arm-$TOOLCHAIN_VERSION-x86_64-arm-linux-gnueabihf"
TOOLCHAIN_URL="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/$TOOLCHAIN_VERSION/binrel/$TOOLCHAIN.tar.xz"
# arm64 rootfs and toolchain
ARM64_TOOLCHAIN="gcc-arm-$TOOLCHAIN_VERSION-x86_64-aarch64-none-linux-gnu"
ARM64_TOOLCHAIN_URL="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/$TOOLCHAIN_VERSION/binrel/$ARM64_TOOLCHAIN.tar.xz"

# debian rootfs images
DEBIAN_SUITE="sid"
ROOTFS_BASE_URL="https://people.collabora.com/~eballetbo/debian/images/"

# Fedora rootfs images
GETFEDORA="https://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Workstation/aarch64/images/"

KERNEL_URL="git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"

# Current Working Directory
CWD=$PWD

