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
    local arg_ret="${1-1}"

    echo "
Chromebook developer tool.

Environment variables:

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
  and --architecture are compulsory.

  --storage=PATH
    Path to the Chromebook storage device or directory i.e.
      /dev/sdb for the SD card.
      /srv/nfs/rootfs for a NFS mount point.
"
echo "  --architecture=ARCH
    Chromebook architecture, needs to be one of the following: arm | arm64 | x86_64"

echo "Supported devices:

"
for chromebook_variant in "${!chromebook_names[@]}"
do
    echo "      $chromebook_variant (${chromebook_names[$chromebook_variant]})"
done

echo "Available commands:

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

opts=$(getopt -o "s:" -l "storage:,architecture:" -- "$@")
eval set -- "$opts"

while true; do
    case "$1" in
        --storage)
            CB_SETUP_STORAGE="$2"
            shift 2
            ;;
        --architecture)
            CB_SETUP_ARCH="$2"
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

[ -n "$CB_SETUP_STORAGE" ] || {
    echo "Incorrect path/storage device passed to the --storage option."
    print_usage_exit
}

if [ -b "$CB_SETUP_STORAGE" ]; then
    storage_is_media_device=true
else
    storage_is_media_device=false
fi

[ "$CB_SETUP_ARCH" = "arm" ] || [ "$CB_SETUP_ARCH" == "arm64" ] || [ "$CB_SETUP_ARCH" == "x86_64" ] || {
    echo "Incorrect architecture device passed to the --architecture option."
    print_usage_exit
}

if [ "$CB_SETUP_ARCH" == "x86_64" ]; then
    DEBIAN_ROOTFS_URL="$ROOTFS_BASE_URL/debian-$DEBIAN_SUITE-chromebook-amd64.tar.gz"
elif [ "$CB_SETUP_ARCH" == "arm64" ]; then
    DEBIAN_ROOTFS_URL="$ROOTFS_BASE_URL/debian-$DEBIAN_SUITE-chromebook-$CB_SETUP_ARCH.tar.gz"
    TOOLCHAIN="$ARM64_TOOLCHAIN"
    TOOLCHAIN_URL="$ARM64_TOOLCHAIN_URL"
    [ -z "$CROSS_COMPILE" ] && export CROSS_COMPILE=\
$PWD/$TOOLCHAIN/bin/aarch64-linux-gnu-
else
    DEBIAN_ROOTFS_URL="$ROOTFS_BASE_URL/debian-$DEBIAN_SUITE-chromebook-armhf.tar.gz"
    [ -z "$CROSS_COMPILE" ] && export CROSS_COMPILE=\
$PWD/$TOOLCHAIN/bin/arm-linux-gnueabihf-
fi

export ARCH=$CB_SETUP_ARCH

# -----------------------------------------------------------------------------
# Utility functions

jopt()
{
    echo "-j"$(grep -c processor /proc/cpuinfo)
}

ensure_command() {
    # ensure_command foo foo-package
    sudo which "$1" 2>/dev/null 1>/dev/null || (
        echo "Install required command $1 from package $2, e.g. sudo apt-get install $2"
        exit 1
    )
}

find_partitions_by_id()
{
    unset CB_SETUP_STORAGE1 CB_SETUP_STORAGE2

    for device in /dev/disk/by-id/*; do
        if [ `realpath $device` = $CB_SETUP_STORAGE ]; then
            if echo "$device" | grep -q -- "-part[0-9]*$"; then
                echo "device $MMC must not be a partition part ($device)" 1>&2
                exit 1
            fi
            for part_id in `ls "$device-part"*`; do
                local part=`realpath $part_id`
                local part_no=`echo $part_id | sed -e 's/.*-part//g'`
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
        if [ `realpath $device` = $CB_SETUP_STORAGE ]; then
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
    if [ "$CB_SETUP_ARCH" != "x86_64" ]; then
         # Devicetree binaries
         local dtbs=""

         # Compress image
         rm -f arch/${CB_SETUP_ARCH}/boot/Image.lz4 || true
         lz4 arch/${CB_SETUP_ARCH}/boot/Image arch/${CB_SETUP_ARCH}/boot/Image.lz4

         if [ "$CB_SETUP_ARCH" == "arm" ]; then
             dtbs="-b arch/arm/boot/dts/rk3288-veyron-minnie.dtb \
                   -b arch/arm/boot/dts/rk3288-veyron-jerry.dtb"
         else
             dtbs="-b arch/arm64/boot/dts/rockchip/rk3399-gru-kevin.dtb"
         fi

         mkimage -D "-I dts -O dtb -p 2048" -f auto -A ${CB_SETUP_ARCH} -O linux -T kernel -C lz4 -a 0 \
                 -d arch/${CB_SETUP_ARCH}/boot/Image.lz4 $dtbs \
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
    read -p "Continue? [N/y] " yn
    [ "$yn" = "y" ] || {
        echo "Aborted"
        exit 1
    }

    # Unmount any partitions automatically mounted
    sudo umount "$CB_SETUP_STORAGE"* > /dev/null 2>&1 || true

    # Clear the partition table
    sudo sgdisk -Z "$CB_SETUP_STORAGE"

    # Create the boot partition and set it as bootable
    sudo sgdisk -n 1:0:+16M -t 1:7f00 "$CB_SETUP_STORAGE"

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
    ROOTFS_DIR=`findmnt -n -o TARGET --source $CB_SETUP_STORAGE2`

    # Verify that the disk is mounted, otherwise exit
    if [ -z "$ROOTFS_DIR" ]; then exit 1; fi

    echo "Done."
}

cmd_setup_rootfs()
{
    local debian_url="${1:-$DEBIAN_ROOTFS_URL}"
    local debian_archive=$(basename $debian_url)

    # Download the Debian rootfs archive if it's not already there.
    if [ ! -f "$debian_archive" ]; then
        echo "Rootfs archive not found, downloading from $debian_url"
        wget "$debian_url"
    fi

    # Untar the rootfs archive.
    echo "Extracting files onto the partition"
    sudo tar xf "$debian_archive" -C "$ROOTFS_DIR"

    echo "Done."
}

cmd_get_toolchain()
{
    if [ "$CB_SETUP_ARCH" == "x86_64" ]; then
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
    echo "Creating initial git repository if not already present..."

    local arg_url="${1-$KERNEL_URL}"

    # 1. Create initial git repository if not already present
    # 2. Checkout the latest release tagged
    [ -d kernel ] || {
        git clone "$arg_url" kernel
        cd kernel
        local tag=$(git describe --abbrev=0 --exclude="*rc*")
	git checkout ${tag} -b release-${tag}
	cd - > /dev/null
    }

    echo "Done."
}

cmd_config_kernel()
{
    echo "Configure the kernel..."

    cd kernel

    # Create .config
    if [ "$CB_SETUP_ARCH" == "arm" ]; then
        scripts/kconfig/merge_config.sh -m arch/arm/configs/multi_v7_defconfig $CWD/fragments/multi-v7/chromebooks.cfg
        make olddefconfig
    elif [ "$CB_SETUP_ARCH" == "arm64" ]; then
        scripts/kconfig/merge_config.sh -m arch/arm64/configs/defconfig $CWD/fragments/arm64/chromebooks.cfg
        make olddefconfig
    else
        scripts/kconfig/merge_config.sh -m arch/x86/configs/x86_64_defconfig $CWD/fragments/x86_64/chromebooks.cfg
        make olddefconfig
    fi

    cd - > /dev/null

    echo "Done."
}

cmd_build_kernel()
{
    echo "Build kernel, modules and the device tree blob..."

    cd kernel

    # Build kernel + modules + device tree blob
    if [ "$CB_SETUP_ARCH" == "arm" ]; then
        make zImage modules dtbs $(jopt)
    else
	    make $(jopt)
    fi

    create_fit_image

    cd - > /dev/null

    echo "Done."
}

cmd_deploy_kernel_modules()
{
    echo "Deploy the kernel modules on the rootfs..."

    cd kernel

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

    echo "Sign the kernels to boot with Chrome OS devices..."

    case "$CB_SETUP_ARCH" in
        arm|arm64)
            arch="arm"
            bootloader="boot_params"
            vmlinuz="kernel/kernel.itb"
            ;;
        x86_64)
            arch="x86"
            bootloader="./bootstub/bootstub.efi"
            vmlinuz="kernel/arch/x86/boot/bzImage"
            ;;
        *)
            echo "Unsupported vboot architecture"
	    exit 1
            ;;
    esac

    echo "root=PARTUUID=%U/PARTNROFF=1 rootwait rw" > boot_params
    sudo vbutil_kernel --pack kernel/kernel.vboot \
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
    echo "Deploy vboot image on the boot partition..."

    if $storage_is_media_device; then
        find_partitions_by_id

        # Install it on the boot partition
        local boot="$CB_SETUP_STORAGE1"
        sudo dd if=kernel/kernel.vboot of="$boot" bs=4M
    else
        if [ "$CB_SETUP_ARCH" != "x86_64" ]; then
            sudo cp -av kernel/kernel.itb "$ROOTFS_DIR/boot"
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

# These commands are required
ensure_command curl curl
ensure_command findmnt util-linux
ensure_command realpath realpath
ensure_command sgdisk gdisk
ensure_command mkfs.ext4 e2fsprogs
ensure_command mkimage u-boot-tools
ensure_command udisksctl udisks2
ensure_command vbutil_kernel vboot-utils
ensure_command wget wget

# Run the command if it's valid, otherwise abort
type cmd_$cmd > /dev/null 2>&1 || print_usage_exit
cmd_$cmd $@

exit 0
