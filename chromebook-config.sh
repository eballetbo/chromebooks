# chromebook-config.sh - Configuration file for chromebook-setup

# default rootfs and toolchain (arm)
DEBIAN_ROOTFS_URL="https://people.collabora.com/~eballetbo/debian/images/debian-stretch-chromebook-armhf.tar.gz"
TOOLCHAIN="gcc-linaro-7.2.1-2017.11-x86_64_arm-linux-gnueabihf"
TOOLCHAIN_URL="http://releases.linaro.org/components/toolchain/binaries/7.2-2017.11/arm-linux-gnueabihf/$TOOLCHAIN.tar.xz"
# arm64 rootfs and toolchain
ARM64_DEBIAN_ROOTFS_URL="https://people.collabora.com/~eballetbo/debian/images/debian-stretch-chromebook-arm64.tar.gz"
ARM64_TOOLCHAIN="gcc-linaro-7.2.1-2017.11-x86_64_aarch64-linux-gnu"
ARM64_TOOLCHAIN_URL="http://releases.linaro.org/components/toolchain/binaries/7.2-2017.11/aarch64-linux-gnu/$ARM64_TOOLCHAIN.tar.xz"

KERNEL_URL="git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"

# Current Working Directory
CWD=$PWD

# Chromebook-specific config.

declare -A chromebook_names=(
    ["C100PA"]="ASUS Chromebook Flip C100PA"
    ["NBCJ2"]="CTL J2 Chromebook for Education"
    ["XE513C24"]="Samsung Chromebook Plus"
)

# Function to retrieve keys/values from associative array using indirection.

get_assoc_keys() {
    eval "echo \${!$1[@]}"
}

get_assoc_vals() {
    eval "echo \${$1[$2]}"
}
