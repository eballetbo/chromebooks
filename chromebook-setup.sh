#!/usr/bin/env bash
# This file:
#
#  - ARM Chromebook developer tool to create a Debian bootable media device.
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
ARM Chromebook developer tool.

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
  and --variant are compulsory, the --mali option has a default value
  to use the latest driver available.

  --storage=PATH
    Path to the Chromebook storage device i.e. the SD card.
"
echo "  --variant=VARIANT
    Chromebook variant, needs to be one of the following:"

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

  setup_rootfs [ARCHIVE]
    Install the rootfs on the storage device specified with --storage.
    The root partition will first be mounted in a local rootfs
    directory, then the rootfs archive will be extracted onto it.  If
    ARCHIVE is not provided then the default one will be automatically
    downloaded and used.  The partition will then remain mounted in
    order to run other commands.  The standard rootfs URL is:
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
    Compile the Linux kernel and install the modules on the rootfs.

  build_vboot [ROOT]
    Build vboot and install it along with the kernel main image on the
    boot partition of the storage device.  The optional ROOT argument
    is the root device to pass to the kernel, by default the standard
    one for SD cards:
        $ROOT_DEFAULT

For example, to do everything for the ASUS Chromebook Flip C100PA:

  $0 do_everything --variant=C100PA --storage=/dev/sdX
"

    exit $arg_ret
}

opts=$(getopt -o "s:" -l "storage:,variant:" -- "$@")
eval set -- "$opts"

while true; do
    case "$1" in
        --storage)
            CB_SETUP_STORAGE="$2"
            shift 2
            ;;
        --variant)
            CB_SETUP_VARIANT="$2"
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

[ -n "$CB_SETUP_STORAGE" ] && [ -b "$CB_SETUP_STORAGE" ] || {
    echo "Incorrect storage device passed to the --storage option."
    print_usage_exit
}

if [ -z "${chromebook_names[$CB_SETUP_VARIANT]}" ]; then
    echo "Unknown Chromebook variant passed to the --variant option."
    print_usage_exit
else
    echo "Configured for ${chromebook_names[$CB_SETUP_VARIANT]}"
fi

[ -z "$CROSS_COMPILE" ] && export CROSS_COMPILE=\
$PWD/$TOOLCHAIN/bin/arm-linux-gnueabihf-

export ARCH=arm

# -----------------------------------------------------------------------------
# Utility functions

jopt()
{
    echo "-j"$(grep -c processor /proc/cpuinfo)
}

# -----------------------------------------------------------------------------
# Functions to run each command

cmd_help()
{
    print_usage_exit 0
}

cmd_format_storage()
{
    echo "Creating partitions on $CB_SETUP_STORAGE"
    df 2>&1 | grep "$CB_SETUP_STORAGE" || true
    read -p "Continue? [N/y] " yn
    [ "$yn" = "y" ] || {
        echo "Aborted"
        exit 1
    }

    # Unmount any partitions automatically mounted
    sudo umount "$CB_SETUP_STORAGE"? || true

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
    sudo mkfs.ext4 -L ROOT-A "$CB_SETUP_STORAGE"2

    echo "Done."
}

cmd_setup_rootfs()
{
    local debian_url="${1:-$DEBIAN_ROOTFS_URL}"
    local debian_archive=$(basename $debian_url)

    echo "Mounting rootfs partition in $ROOTFS_DIR"
    local part="$CB_SETUP_STORAGE"2
    mkdir -p "$ROOTFS_DIR"
    sudo umount "$ROOTFS_DIR" || true
    sudo mount "$part" "$ROOTFS_DIR"

    # Download the Debian rootfs archive if it's not already there.
    if [ ! -f "$debian_archive" ]; then
        echo "Rootfs archive not found, downloading from $debian_url"
        wget "$debian_url"
    fi

    # Untar the rootfs archive.
    echo "Extracting files onto the partition"
    sudo tar xf "$debian_archive" -C "$ROOTFS_DIR" binary --strip=1

    echo "Done."
}

cmd_get_toolchain()
{
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
    local arg_url="${1-$KERNEL_URL}"

    # Create initial git repository if not already present
    [ -d kernel ] || {
        echo "Getting kernel repository"
        git clone "$arg_url" kernel
    }

    cd kernel

    cd - > /dev/null

    echo "Done."
}

cmd_config_kernel()
{
    cd kernel

    # Create .config
    scripts/kconfig/merge_config.sh -m arch/arm/configs/multi_v7_defconfig $CWD/fragments/multi-v7/veyron.cfg

    make olddefconfig

    cd - > /dev/null

    echo "Done."
}

cmd_build_kernel()
{
    # TODO: check vboot-utils is installed

    cd kernel

    # Build kernel + modules + device tree blob
    make zImage modules dtbs $(jopt)

    # Make boot image blob
    local kernel_its="/dts-v1/;
    / {
    description = \"Chrome OS kernel image with one or more FDT blobs\";
    #address-cells = <1>;
    images {
        kernel@1{
            description = \"kernel (arm)\";
            data = /incbin/(\"arch/arm/boot/zImage\");
            type = \"kernel\";
            arch = \"arm\";
            os = \"linux\";
            compression = \"none\";
        };
        fdt@1{
            description = \"RK3288 Veyron Minnie\";
            data = /incbin/(\"arch/arm/boot/dts/rk3288-veyron-minnie.dtb\");
            type = \"flat_dt\";
            arch = \"arm\";
            compression = \"none\";
            fdt-version = <1>;
        };
        fdt@2{
            description = \"RK3288 Veyron Jerry\";
            data = /incbin/(\"arch/arm/boot/dts/rk3288-veyron-jerry.dtb\");
            type = \"flat_dt\";
            arch = \"arm\";
            compression = \"none\";
            fdt-version = <1>;
        };
    };
    configurations {
        default = \"conf@1\";
        conf@1{
            kernel = \"kernel@1\";
            fdt = \"fdt@1\";
        };
        conf@2{
            kernel = \"kernel@1\";
            fdt = \"fdt@2\";
        };
      };
    };"

    echo "$kernel_its" > kernel.its
    mkimage -f kernel.its kernel.itb

    # Install the kernel modules on the rootfs
    sudo make modules_install ARCH=arm INSTALL_MOD_PATH=$CWD/ROOT-A

    cd - > /dev/null

    echo "Done."
}

cmd_build_vboot()
{
    # TODO: check vboot-utils is installed

    # Install it on the boot partition
    echo "console=ttyS2,115200n8 console=tty1 init=/sbin/init root=PARTUUID=%U/PARTNROFF=1 rootwait rw noinitrd" > boot_params
    local boot="$CB_SETUP_STORAGE"1
    sudo vbutil_kernel --pack "$boot" --keyblock /usr/share/vboot/devkeys/kernel.keyblock --version 1 --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --bootloader boot_params --config boot_params --vmlinuz kernel/kernel.itb --arch arm

    echo "Done."
}

cmd_do_everything()
{
    cmd_format_storage
    cmd_setup_rootfs
    cmd_get_toolchain
    cmd_get_kernel
    cmd_config_kernel
    cmd_build_kernel
    cmd_build_vboot

    echo "Ejecting storage device..."
    sync
    sudo eject "$CB_SETUP_STORAGE"
    echo "All done."
}

# Run the command if it's valid, otherwise abort
type cmd_$cmd > /dev/null 2>&1 || print_usage_exit
cmd_$cmd $@

exit 0
