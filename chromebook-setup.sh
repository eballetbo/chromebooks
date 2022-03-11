#!/usr/bin/env bash
# This file:
#
#  - Chromebook developer tool to create a Debian bootable media device.
#
# Usage:
#
#  ./chromebook-setup.sh COMMAND [ARGS] OPTIONS
#
# Based on mali_chromebook-setup_006 scripts by Guillaume Tucker
#  - https://community.arm.com/graphics/b/blog/posts/linux-on-chromebook-with-arm-mali-gpu
#

# Exit on error. Append "|| true" if you expect an error.
set -e
# Turn on traces, useful while debugging but commented out by default
#set -x

source chromebook-config.sh

print_usage_exit()
{
    local arg_ret

    arg_ret="${1-1}"

    echo "
Chromebook developer tool.

Environment variables:

  ARCH

    Standard variable to specify the architeture to be built by the
    cross-compiler toolchain.  If it is not already defined before
    calling this script, it will be set to the architecture specified
    with the --architecture option.

  CROSS_COMPILE

    Standard variable to use a cross-compiler toolchain.  If it is not
    already defined before calling this script, it will be set by
    default in this script to match the toolchain downloaded using the
    get_toolchain command.

Usage:

  $0 COMMAND [ARGS] OPTIONS

  Only COMMAND and ARGS are positional arguments; the OPTIONS can be
  placed anywhere and in any order.  The definition of ARGS varies
  with each COMMAND.

Options:

  The following options are common to all commands.  Only --storage
  and --architecture are compulsory but the latter is also optional
  if the ARCH environment variable has already been set.

  --distro=NAME
    Name of the Linux distribution that the kernel needs to support.
    By setting a distro value, Kconfig symbols needed by a particular
    distribution will be included when merging the config fragments.

  --kernel=PATH
    Path to the Linux Git repository used to build the kernel image.
    If is not set, the default is to clone the kernel in $PWD/kernel.

  --storage=PATH
    Path to the Chromebook storage device or directory i.e.
      /dev/sdb for the SD card.
      /srv/nfs/rootfs for a NFS mount point.

  --architecture=ARCH
    Chromebook architecture, needs to be one of the following: arm | arm64 | x86_64

Available commands:

  help
    Print this help message.

  do_everything
    Do everything in one command with default settings.

  format_storage
    Format the storage device to be used as a bootable SD card or USB
    stick on the Chromebook.  The device passed to the --storage
    option is used.

  mount_rootfs
    Mount the root partition in a local rootfs directory.  The partition
    will remain mounted in order to run other commands.

  setup_rootfs [ARCHIVE]
    Install the rootfs on the storage device specified with --storage.
    If ARCHIVE is not provided then the default one will be automatically
    downloaded and used.  The standard rootfs URL is:
        $DEBIAN_ROOTFS_URL

  get_toolchain
    Download and extract the cross-compiler toolchain needed to build
    the Linux kernel.  It is fixed to this version:
        $TOOLCHAIN_URL

    In order to use an alternative toolchain, the CROSS_COMPILE
    environment variable can be set before calling this script to
    point at the toolchain of your choice.

  get_kernel [URL]
    Get the latest kernel source code. The optional URL argument is to
    specify an alternative Git repository, the default one being:
        $KERNEL_URL

  config_kernel
    Configure the Linux kernel.

  build_kernel
    Compile the Linux kernel modules.

  deploy_kernel_modules
    Install the Linux kernel modules on the rootfs.

  build_bootstub
    Build the ChromeOS bootstub.efi.

  build_vboot
    Build vboot image.

  deploy_vboot
    Install the kernel vboot image on the boot partition of the storage
    device.

  eject_storage
    Eject removable media.

Commands useful for development workflow:

  deploy_kernel
    Compile the Linux kernel, its modules, the vboot image and deploy all
    on the storage device.

For example, to do everything on a SD card for the ASUS Chromebook Flip
C100PA (arm):

  $0 do_everything --architecture=arm --storage=/dev/sdX

or to do the same to use NFS for the root filesystem:

  $0 do_everything --architecture=arm --storage=/srv/nfs/nfsroot

"

    exit $arg_ret
}

opts=$(getopt -o "h,s:" -l "help,distro:,kernel:,storage:,architecture:" -- "$@")
eval set -- "$opts"

while true; do
    case "$1" in
        --help|-h)
            print_usage_exit
            ;;
        --distro)
            CB_DISTRO="$2"
            shift 2
            ;;
        --kernel)
            CB_KERNEL_PATH="$2"
            shift 2
            ;;
        --storage)
            CB_SETUP_STORAGE="$2"
            shift 2
            ;;
        --architecture)
            ARCH="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Internal error"
            exit 1
            ;;
    esac
done

cmd="$1"
[ -z "$cmd" ] && print_usage_exit
shift

# -----------------------------------------------------------------------------
# Options sanitising

if [ -z "$CB_KERNEL_PATH" ]; then
    CB_KERNEL_PATH="kernel"
fi

[ -n "$CB_SETUP_STORAGE" ] || {
    echo "Incorrect path/storage device passed to the --storage option."
    print_usage_exit
}

if [ -b "$CB_SETUP_STORAGE" ]; then
    storage_is_media_device=true
else
    storage_is_media_device=false
fi

[[ "$CB_SETUP_STORAGE" = /dev/* ]] && [[ $storage_is_media_device = false ]] && {
    echo "Storage references a dev node, yet not a block device."
    echo "Make sure you've plugged the device and referenced it correctly."
    print_usage_exit
}

[ -z "$ARCH" ] && {
    echo "Architecture was not set."
    print_usage_exit
}

case "$ARCH" in
    arm)
        ARCH="arm"
        ;;
    arm64|aarch64)
        ARCH="arm64"
        ;;
    x86_64|amd64)
        ARCH="x86_64"
        ;;
    *)
        echo "Incorrect architecture $ARCH was set."
        print_usage_exit
        ;;
esac

if [ "$ARCH" == "x86_64" ]; then
    DEBIAN_ROOTFS_URL="$ROOTFS_BASE_URL/debian-gnome-desktop-$DEBIAN_SUITE-amd64.tar.gz"
elif [ "$ARCH" == "arm64" ]; then
    DEBIAN_ROOTFS_URL="$ROOTFS_BASE_URL/debian-gnome-desktop-$DEBIAN_SUITE-$ARCH.tar.gz"
    TOOLCHAIN="$ARM64_TOOLCHAIN"
    TOOLCHAIN_URL="$ARM64_TOOLCHAIN_URL"
    [ -z "$CROSS_COMPILE" ] && export CROSS_COMPILE=\
$PWD/$TOOLCHAIN/bin/aarch64-none-linux-gnu-
else
    DEBIAN_ROOTFS_URL="$ROOTFS_BASE_URL/debian-gnome-desktop-$DEBIAN_SUITE-armhf.tar.gz"
    [ -z "$CROSS_COMPILE" ] && export CROSS_COMPILE=\
$PWD/$TOOLCHAIN/bin/arm-none-linux-gnueabihf-
fi

export ARCH

# -----------------------------------------------------------------------------
# Utility functions

jopt()
{
    echo "-j"$(grep -c processor /proc/cpuinfo)
}

ensure_command() {
    # ensure_command foo foo-package
    which "$1" 2>/dev/null 1>/dev/null ||
    sudo which "$1" 2>/dev/null 1>/dev/null || (
        echo "Install required command $1 from package $2, e.g. sudo $pkg_mgr install $2"
        exit 1
    )
}

find_partitions_by_id()
{
    unset CB_SETUP_STORAGE1 CB_SETUP_STORAGE2

    for device in /dev/disk/by-id/*; do
        if [ "$(realpath $device)" = $CB_SETUP_STORAGE ]; then
            if echo "$device" | grep -q -- "-part[0-9]*$"; then
                echo "device $MMC must not be a partition part ($device)" 1>&2
                exit 1
            fi
            for part_id in "$device-part"*; do
                local part
                local part_no

                part="$(realpath $part_id)"
                part_no="$(echo $part_id | sed -e 's/.*-part//g')"
                if test "$part_no" = 1; then
                    CB_SETUP_STORAGE1=$part
                elif test "$part_no" = 2; then
                    CB_SETUP_STORAGE2=$part
                fi
            done
	    break
        fi
    done
}

wait_for_partitions_to_appear()
{
    for device in /dev/disk/by-id/*; do
        if [ "$(realpath $device)" = $CB_SETUP_STORAGE ]; then
            if echo "$device" | grep -q -- "-part[0-9]*$"; then
                echo "device $CB_SETUP_STORAGE must not be a partition part ($device)" 1>&2
                exit 1
            fi

            if [ ! -e ${device}-part1 ]; then
                echo -n "Waiting for partitions to appear ."

                while [ ! -e ${device}-part1 ]
                do
                    sleep 1
                    echo -n "."
                done
                echo " done"
            fi
        fi
    done
}

create_fit_image()
{
    if [ "$ARCH" != "x86_64" ]; then
         # Devicetree binaries
         local dtbs=""
         local kernel=""
         local compression=""

         if [ "$ARCH" == "arm" ]; then
             kernel="zImage"
             compression="none"
             dtbs=" \
                   -b arch/arm/boot/dts/exynos5250-snow.dtb \
                   -b arch/arm/boot/dts/rk3288-veyron-minnie.dtb \
                   -b arch/arm/boot/dts/rk3288-veyron-jerry.dtb"
         else
             kernel="Image.lz4"
             compression="lz4"

             # Compress image
             rm -f arch/${ARCH}/boot/Image.lz4 || true
             lz4 arch/${ARCH}/boot/Image arch/${ARCH}/boot/Image.lz4

             dtbs=" \
		    -b arch/arm64/boot/dts/qcom/sc7180-trogdor-coachz-r3.dtb \
		    -b arch/arm64/boot/dts/qcom/sc7180-trogdor-lazor-r3-kb.dtb \
		    -b arch/arm64/boot/dts/mediatek/mt8173-elm.dtb \
		    -b arch/arm64/boot/dts/mediatek/mt8173-elm-hana.dtb \
		    -b arch/arm64/boot/dts/mediatek/mt8183-kukui-krane-sku176.dtb \
		    -b arch/arm64/boot/dts/rockchip/rk3399-gru-kevin.dtb\
		    -b arch/arm64/boot/dts/rockchip/rk3399-gru-scarlet-inx.dtb \
                  "
         fi

         mkimage -D "-I dts -O dtb -p 2048" -f auto -A ${ARCH} -O linux -T kernel -C $compression -a 0 \
                 -d arch/${ARCH}/boot/$kernel $dtbs \
                 kernel.itb
    else
	echo "TODO: create x86_64 FIT image, now using a raw image"
    fi
}

# -----------------------------------------------------------------------------
# Functions to run each command

cmd_help()
{
    print_usage_exit 0
}

cmd_format_storage()
{
    # Skip this command if is not a media device.
    if ! $storage_is_media_device; then return 0; fi

    echo "Creating partitions on $CB_SETUP_STORAGE"
    df 2>&1 | grep "$CB_SETUP_STORAGE" || true
    read -rp "Continue? [N/y] " yn
    [ "$yn" = "y" ] || {
        echo "Aborted"
        exit 1
    }

    # Unmount any partitions automatically mounted
    sudo umount "$CB_SETUP_STORAGE"* > /dev/null 2>&1 || true

    # Clear the partition table
    sudo sgdisk -Z "$CB_SETUP_STORAGE"

    # Create the boot partition and set it as bootable
    sudo sgdisk -n 1:0:+64M -t 1:7f00 "$CB_SETUP_STORAGE"

    # Set special metadata understood by the Chromebook.  These flags
    # are not standard thus do not have names.  For more details, see
    # the cgpt sources which can be found in vboot_reference chromiumos
    # repository.
    sudo sgdisk -A 1:set:48 -A 1:set:56 "$CB_SETUP_STORAGE"

    # Create and format the root partition
    sudo sgdisk -n 2:0:0 -t 2:7f01 "$CB_SETUP_STORAGE"

    # Tell the system to refresh what it knows about the disk partitions
    sudo partprobe "$CB_SETUP_STORAGE"

    wait_for_partitions_to_appear
    find_partitions_by_id

    sudo mkfs.ext4 -L ROOT-A "$CB_SETUP_STORAGE2"

    echo "Done."
}

cmd_mount_rootfs()
{
    # Skip this command if is not a media device.
    if ! $storage_is_media_device; then return 0; fi

    find_partitions_by_id

    echo "Mounting rootfs partition..."

    udisksctl mount -b "$CB_SETUP_STORAGE2" > /dev/null 2>&1 || true
    ROOTFS_DIR="$(findmnt -n -o TARGET --source $CB_SETUP_STORAGE2)"

    # Verify that the disk is mounted, otherwise exit
    if [ -z "$ROOTFS_DIR" ]; then exit 1; fi

    echo "Done."
}

cmd_setup_rootfs()
{
    local debian_url
    local debian_archive

    debian_url="${1:-$DEBIAN_ROOTFS_URL}"
    debian_archive=$(basename $debian_url)

    echo "$debian_url"
    if test -d "$debian_url"; then
        # Copy the rootfs directory.
        echo "Copying files into the partition"
        sudo cp -a "$debian_url"/* "$ROOTFS_DIR"
    else
        # Download the Debian rootfs archive if it is not already there.
        if [ ! -f "$debian_archive" ]; then
            echo "Rootfs archive not found, downloading from $debian_url"
            curl -OL "$debian_url"
        fi

        # Untar the rootfs archive.
        echo "Extracting files onto the partition"
        sudo tar xf "$debian_archive" -C "$ROOTFS_DIR"
    fi

    echo "Done."
}

cmd_get_toolchain()
{
    if [ "$ARCH" == "x86_64" ]; then
        echo "Using default distro toolchain"
        return 0
    fi

    [ -d "$TOOLCHAIN" ] && {
        echo "Toolchain already downloaded: $TOOLCHAIN"
        return 0
    }

    echo "Downloading and extracting toolchain: $url"
    curl -L "$TOOLCHAIN_URL" | tar xJf -

    echo "Done."
}

cmd_get_kernel()
{
    local arg_url
    local tag

    echo "Creating initial git repository if not already present..."

    arg_url="${1-$KERNEL_URL}"

    # 1. Create initial git repository if not already present
    # 2. Checkout the latest release tagged
    [ -d ${CB_KERNEL_PATH} ] || {
        git clone "$arg_url" ${CB_KERNEL_PATH}
        cd ${CB_KERNEL_PATH}
        tag=$(git describe --abbrev=0 --exclude="*rc*")
        if test ${KERNEL_TAG}; then
            tag=${KERNEL_TAG}
        fi
        git checkout ${tag} -b release-${tag}
        cd - > /dev/null
    }

    echo "Done."
}

cmd_config_kernel()
{
    echo "Configure the kernel..."

    cd $CB_KERNEL_PATH

    if [ -n "$CB_DISTRO" ]; then
        if ! [ -f $CWD/fragments/distro/$CB_DISTRO.cfg ]; then
            echo "Distro $CB_DISTRO is not supported yet"
            print_usage_exit
        fi
        DISTRO_CFG="$CWD/fragments/distro/$CB_DISTRO.cfg"
    fi

    # Create .config
    if [ "$ARCH" == "arm" ]; then
        scripts/kconfig/merge_config.sh -m arch/arm/configs/multi_v7_defconfig $DISTRO_CFG $CWD/fragments/multi-v7/chromebooks.cfg
        make olddefconfig
    elif [ "$ARCH" == "arm64" ]; then
        scripts/kconfig/merge_config.sh -m arch/arm64/configs/defconfig $DISTRO_CFG $CWD/fragments/arm64/chromebooks.cfg $CWD/fragments/arm64/mediatek.cfg $CWD/fragments/arm64/qualcomm.cfg
        make olddefconfig
    else
        scripts/kconfig/merge_config.sh -m arch/x86/configs/x86_64_defconfig $DISTRO_CFG $CWD/fragments/x86_64/chromebooks.cfg
        make olddefconfig
    fi

    cd - > /dev/null

    echo "Done."
}

cmd_build_kernel()
{
    echo "Build kernel, modules and the device tree blob..."

    cd ${CB_KERNEL_PATH}

    # Build kernel + modules + device tree blob
    if [ "$ARCH" == "arm" ]; then
        make W=1 zImage modules dtbs $(jopt)
    else
	    make W=1 $(jopt)
    fi

    create_fit_image

    cd - > /dev/null

    echo "Done."
}

cmd_deploy_kernel_modules()
{
    echo "Deploy the kernel modules on the rootfs..."

    cd ${CB_KERNEL_PATH}

    # Install the kernel modules on the rootfs
    sudo make modules_install INSTALL_MOD_PATH=$ROOTFS_DIR

    cd - > /dev/null

    echo "Done."
}

cmd_build_bootstub()
{
   echo "Build bootstub.efi..."

   cd bootstub

   make PREFIX=""

   cd - > /dev/null

   echo "Done."
}

cmd_build_vboot()
{
    local arch
    local bootloader
    local vmlinuz
    local extra_kparams

    echo "Sign the kernels to boot with Chrome OS devices..."

    case "$ARCH" in
        arm|arm64)
            arch="arm"
            bootloader="boot_params"
            vmlinuz="$CB_KERNEL_PATH/kernel.itb"
            ;;
        x86_64)
            arch="x86"
            [ -f ./bootstub/bootstub.efi ] || cmd_build_bootstub
            bootloader="./bootstub/bootstub.efi"
            vmlinuz="$CB_KERNEL_PATH/arch/x86/boot/bzImage"
            extra_kparams="tpm_tis.force=1 tpm_tis.interrupts=0"
            ;;
        *)
            echo "Unsupported vboot architecture"
	    exit 1
            ;;
    esac

    echo "root=PARTUUID=%U/PARTNROFF=1 rootwait rw ${extra_kparams}" > boot_params
    sudo vbutil_kernel --pack $CB_KERNEL_PATH/kernel.vboot \
                       --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
                       --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
                       --version 1 --config boot_params \
                       --bootloader $bootloader \
                       --vmlinuz $vmlinuz \
                       --arch $arch

    echo "Done."
}

cmd_deploy_vboot()
{
    local boot

    echo "Deploy vboot image on the boot partition..."

    if $storage_is_media_device; then
        find_partitions_by_id

        # Install it on the boot partition
        boot="$CB_SETUP_STORAGE1"
        sudo dd if=$CB_KERNEL_PATH/kernel.vboot of="$boot" bs=4M
    else
        if [ "$ARCH" != "x86_64" ]; then
            sudo cp -av $CB_KERNEL_PATH/kernel.itb "$ROOTFS_DIR/boot"
	    else
            echo "WARNING: Not implemented for x86_64."
	    fi
    fi

    echo "Done."
}

cmd_eject_storage()
{
    # Skip this command if is not a media device.
    if ! $storage_is_media_device; then return 0; fi

    echo "Ejecting storage device..."

    udisksctl unmount -b "$CB_SETUP_STORAGE2"
    udisksctl power-off -b "$CB_SETUP_STORAGE" > /dev/null 2>&1 || true

    echo "All done."
}

cmd_do_everything()
{
    cmd_format_storage
    cmd_mount_rootfs
    cmd_setup_rootfs
    cmd_get_toolchain
    cmd_get_kernel
    cmd_config_kernel
    cmd_build_kernel
    cmd_deploy_kernel_modules
    cmd_build_vboot
    cmd_deploy_vboot
    cmd_eject_storage
}

# -----------------------------------------------------------------------------
# Commands for development workflow

cmd_deploy_kernel()
{
    cmd_mount_rootfs
    cmd_build_kernel
    cmd_deploy_kernel_modules
    cmd_build_vboot
    cmd_deploy_vboot
    cmd_eject_storage
}

cmd_deploy_kernel_only()
{
    cmd_mount_rootfs
    cmd_build_kernel
    cmd_build_vboot
    cmd_deploy_vboot
    cmd_eject_storage
}

if grep -qi fedora /etc/os-release; then
  pkg_mgr="dnf"
else
  pkg_mgr="apt"
fi

# These commands are required
ensure_command bc bc
ensure_command curl curl
ensure_command findmnt util-linux
ensure_command realpath realpath
ensure_command sgdisk gdisk
ensure_command lz4 lz4
ensure_command mkfs.ext4 e2fsprogs
ensure_command mkimage u-boot-tools
ensure_command udisksctl udisks2
ensure_command vbutil_kernel vboot-utils

# Run the command if it's valid, otherwise abort
type cmd_$cmd > /dev/null 2>&1 || print_usage_exit
cmd_$cmd "$@"

exit 0
