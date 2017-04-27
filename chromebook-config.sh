# chromebook-config.sh - Configuration file for chromebook-setup

DEBIAN_ROOTFS_URL="http://releases.linaro.org/debian/images/developer-armhf/17.01/linaro-jessie-developer-20161117-32.tar.gz"
TOOLCHAIN="gcc-linaro-4.9.4-2017.01-x86_64_arm-linux-gnueabihf"
TOOLCHAIN_URL="http://releases.linaro.org/components/toolchain/binaries/4.9-2017.01/arm-linux-gnueabihf/$TOOLCHAIN.tar.xz"
KERNEL_URL="git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
ROOTFS_DIR="$PWD/ROOT-A"
ROOT_DEFAULT="/dev/mmcblk1p2"

# Current Working Directory
CWD=$PWD

# Chromebook-specific config.

declare -A chromebook_names=(
    ["C100PA"]="ASUS Chromebook Flip C100PA"
    ["NBCJ2"]="CTL J2 Chromebook for Education"
)

# Function to retrieve keys/values from associative array using indirection.

get_assoc_keys() {
    eval "echo \${!$1[@]}"
}

get_assoc_vals() {
    eval "echo \${$1[$2]}"
}
