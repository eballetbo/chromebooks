# chromebook-config.sh - Configuration file for chromebook-setup

# default rootfs and toolchain (arm)
DEBIAN_ROOTFS_URL="https://people.collabora.com/~eballetbo/debian/images/debian-stretch-chromebook-armhf.tar.gz"
TOOLCHAIN="gcc-arm-8.2-2018.08-x86_64-arm-linux-gnueabihf"
TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu-a/8.2-2018.08/$TOOLCHAIN.tar.xz"
# arm64 rootfs and toolchain
ARM64_DEBIAN_ROOTFS_URL="https://people.collabora.com/~eballetbo/debian/images/debian-stretch-chromebook-arm64.tar.gz"
ARM64_TOOLCHAIN="gcc-arm-8.2-2018.08-x86_64-aarch64-linux-gnu"
ARM64_TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu-a/8.2-2018.08/$ARM64_TOOLCHAIN.tar.xz"

KERNEL_URL="git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"

# Current Working Directory
CWD=$PWD

# Chromebook-specific config.

declare -A chromebook_names=(
    ["C100PA"]="ASUS Chromebook Flip C100PA"
    ["NBCJ2"]="CTL J2 Chromebook for Education"
    ["XE513C24"]="Samsung Chromebook Plus"
)

