# chromebook-config.sh - Configuration file for chromebook-setup

TOOLCHAIN_VERSION="9.2-2019.12"

# default rootfs and toolchain (arm)
TOOLCHAIN="gcc-arm-$TOOLCHAIN_VERSION-x86_64-arm-linux-gnueabihf"
TOOLCHAIN_URL="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/$TOOLCHAIN_VERSION/binrel/$TOOLCHAIN.tar.xz"
# arm64 rootfs and toolchain
ARM64_TOOLCHAIN="gcc-arm-$TOOLCHAIN_VERSION-x86_64-aarch64-none-linux-gnu"
ARM64_TOOLCHAIN_URL="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/$TOOLCHAIN_VERSION/binrel/$ARM64_TOOLCHAIN.tar.xz"

# debian rootfs images
DEBIAN_SUITE="sid"
ROOTFS_BASE_URL="https://people.collabora.com/~eballetbo/debian/images/"

KERNEL_URL="git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"

# Current Working Directory
CWD=$PWD

# Chromebook-specific config.

declare -A chromebook_names=(
    ["C100PA"]="ASUS Chromebook Flip C100PA"
    ["NBCJ2"]="CTL J2 Chromebook for Education"
    ["XE513C24"]="Samsung Chromebook Plus"
)

