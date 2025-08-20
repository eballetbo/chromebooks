#!/usr/bin/env bash

# SPDX-License-Identifier:  GPL-2.0+
# Chromebook Developer Tool to automate the creation of media bootable devices for Chromebooks
#
# Usage:
#
#  ./chromebook-setup.sh COMMAND [ARGS] OPTIONS
#
# Based on mali_chromebook-setup_006 scripts by Guillaume Tucker
#  - https://community.arm.com/arm-community-blogs/b/graphics-gaming-and-vr-blog/posts/linux-on-chromebook-with-arm-mali-gpu
#
# shellcheck disable=SC2317  # Don't warn about unreachable commands in this file
# shellcheck disable=SC2086  # Double quote to prevent globbing and word splitting

# Exit on error. Append "|| true" if you expect an error.
set -e
# Turn on traces, useful while debugging but commented out by default
#set -x

# Fedora rootfs images
GETFEDORA="https://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Workstation/aarch64/images/"

KERNEL_URL="git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"

# Current Working Directory
CWD=$PWD

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
    default in this script to match aarch64-linux-gnu-.

Usage:

  sudo $0 COMMAND [ARGS] OPTIONS

  Only COMMAND and ARGS are positional arguments; the OPTIONS can be
  placed anywhere and in any order.  The definition of ARGS varies
  with each COMMAND.

Options:

  The following options are common to all commands.  Only --storage
  and --architecture are compulsory but the latter is also optional
  if the ARCH environment variable has already been set.

  --image=IMAGE
    This is the uncompressed raw image file name.
    Example: --image=Fedora-Workstation-36-1.5.aarch64.raw

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

  --kparams=PARAMETERS
    Additional parameters to be added to the kernel command line.

  --initrd=INITRD
    Initrd to be added to the FIT image.

  --enable-copr=COPR
    When this is enabled, instead of install the kernel from the image, it
    downloads and installs the kernel from the copr repository provided.

  --pkgversion=PKGVERSION
    This variable sets the fedora package version. It is used to download a
    specific version of the fedora kernel package.

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

  setup_rootfs
    Install the rootfs on the storage device specified with --storage.

  deploy_fedora
    prepare media for fedora ARM
    For example, to deploy the default Fedora Image:

        $0 deploy_fedora --image=name.raw --architecture=arm64 --storage=/dev/sdX

  deploy_fedora_kernel
    Install a Fedora Linux kernel as a vboot image and its modules on the rootfs.
    The rootfs must had been setup previously using the deploy_fedora command.

  setup_fedora_rootfs
    Install the fedora rootfs on the storage device specified with --storage.
    if no archive is provided the default one is used:
        $GETFEDORA

  setup_fedora_kernel
    Download and extract a known kernel that works for chromebooks
    this also copies the kernel packages to the fedora rootfs and generate
    modules.dep and map files, to enable modules autoload on first boot.

  get_kernel
    Get the latest kernel source code. The default Git repository is:
        $KERNEL_URL

  config_kernel
    Configure the Linux kernel.

  build_kernel
    Compile the Linux kernel modules.

  deploy_kernel
   Install the Linux kernel as a vboot image and its modules on the rootfs.

  deploy_kernel_only
   Install only the Linux kernel as a vboot image but no its modules.

  deploy_kernel_modules
    Install only the Linux kernel modules on the rootfs but no the image.

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

  sudo $0 do_everything --architecture=aarch64 --storage=/dev/sdX

or to do the same to use NFS for the root filesystem:

  sudo $0 do_everything --architecture=aarch64 --storage=/srv/nfs/nfsroot

"

    exit $arg_ret
}

opts=$(getopt -o "h,s:" -l "help,image:,distro:,kernel:,storage:,architecture:,kparams:,initrd:,enable-copr:,pkgversion:" -- "$@")
eval set -- "$opts"

while true; do
    case "$1" in
        --help|-h)
            print_usage_exit
            ;;
        --image)
            IMAGE="$2"
            shift 2
            ;;
        --distro)
            CB_DISTRO="$2"
            shift 2
            ;;
        --kernel)
            KERNEL="$2"
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
        --kparams)
            EXTRA_KPARAMS="$2"
            shift 2
            ;;
        --initrd)
            INITRD="$2"
            shift 2
            ;;
        --enable-copr)
            COPR="$2"
            shift 2
            ;;
        --pkgversion)
            PKGVERSION="$2"
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

if [ -z "$KERNEL" ]; then
    CB_KERNEL_PATH="kernel"
else
    CB_KERNEL_PATH="$KERNEL"
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
        echo "Error: ARMv7 or armhfp architecture is not supported."
        exit 1
        ;;
    arm64|aarch64)
        ARCH="arm64"
        if [ "$(uname -m)" = "x86_64" ]; then
            echo "Building for $ARCH on x86_64 machine, setting cross compilation."
            [ -z "$CROSS_COMPILE" ] && export CROSS_COMPILE=aarch64-linux-gnu-
        fi
        ;;
    x86_64|amd64)
        ARCH="x86_64"
        ;;
    *)
        echo "Incorrect architecture $ARCH was set."
        print_usage_exit
        ;;
esac

export ARCH

# -----------------------------------------------------------------------------
# Utility functions

jopt()
{
    echo "-j$(grep -c processor /proc/cpuinfo)"
}

ensure_command() {
    # ensure_command foo foo-package-fedora [ foo-package-debian ]
    which "$1" 2>/dev/null 1>/dev/null || (
        if grep -qi fedora /etc/os-release; then
            package="$2"
        else
            package="${3:-2}"
        fi
        echo "Install required command $1 from package $package, e.g. sudo $pkg_mgr install $package"
        exit 1
    )
}

vmlinuz_is_an_efi_application() {
    file "$1" | grep -qi "PE32+ executable (EFI application)"
}

find_partitions_by_id()
{
    unset CB_SETUP_STORAGE1 CB_SETUP_STORAGE2

    for device in /dev/disk/by-diskseq/*; do
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
    for device in /dev/disk/by-diskseq/*; do
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
         local initrd=""

         kernel="Image.lz4"
         compression="lz4"

         # Compress image
         rm -f arch/${ARCH}/boot/Image.lz4 || true
         lz4 arch/${ARCH}/boot/Image arch/${ARCH}/boot/Image.lz4

         #fedora kernel does not generate these device-tree
         if [ "$CB_DISTRO" == "fedora" ]; then
            dtbs=" \
                -b arch/arm64/boot/dts/qcom/sc7180-trogdor-coachz-r3.dtb \
                -b arch/arm64/boot/dts/qcom/sc7180-trogdor-lazor-r3-kb.dtb \
                -b arch/arm64/boot/dts/qcom/sc7180-trogdor-wormdingler-rev1-inx.dtb \
                -b arch/arm64/boot/dts/qcom/sc7180-trogdor-wormdingler-rev1-boe-rt5682s.dtb \
                -b arch/arm64/boot/dts/qcom/sc7180-trogdor-wormdingler-rev1-inx-rt5682s.dtb \
                -b arch/arm64/boot/dts/qcom/sc7180-trogdor-wormdingler-rev1-boe.dtb \
                -b arch/arm64/boot/dts/rockchip/rk3399-gru-kevin.dtb \
                -b arch/arm64/boot/dts/rockchip/rk3399-gru-scarlet-inx.dtb \
		-b arch/arm64/boot/dts/mediatek/mt8183-kukui-jacuzzi-kappa.dtb
                "
         else
            dtbs=" \
                -b arch/arm64/boot/dts/qcom/sc7180-trogdor-coachz-r3.dtb \
                -b arch/arm64/boot/dts/qcom/sc7180-trogdor-lazor-r3-kb.dtb \
                -b arch/arm64/boot/dts/qcom/sc7180-trogdor-wormdingler-rev1-inx.dtb \
                -b arch/arm64/boot/dts/qcom/sc7180-trogdor-wormdingler-rev1-boe-rt5682s.dtb \
                -b arch/arm64/boot/dts/qcom/sc7180-trogdor-wormdingler-rev1-inx-rt5682s.dtb \
                -b arch/arm64/boot/dts/qcom/sc7180-trogdor-wormdingler-rev1-boe.dtb \
                -b arch/arm64/boot/dts/mediatek/mt8173-elm.dtb \
                -b arch/arm64/boot/dts/mediatek/mt8173-elm-hana.dtb \
                -b arch/arm64/boot/dts/mediatek/mt8183-kukui-krane-sku176.dtb \
                -b arch/arm64/boot/dts/mediatek/mt8183-kukui-jacuzzi-kenzo.dtb \
                -b arch/arm64/boot/dts/rockchip/rk3399-gru-kevin.dtb\
                -b arch/arm64/boot/dts/rockchip/rk3399-gru-scarlet-inx.dtb \
		-b arch/arm64/boot/dts/mediatek/mt8183-kukui-jacuzzi-kappa.dtb
                "
         fi

         if [ -n "$INITRD" ]; then
             initrd="-i $INITRD"
         elif [ -f "arch/${ARCH}/boot/initramfs-$kernel_version.img" ]; then
             initrd="-i arch/${ARCH}/boot/initramfs-$kernel_version.img"
         fi
         mkimage -D "-I dts -O dtb -p 2048" -f auto -A ${ARCH} -O linux -T kernel -C $compression -a 0 \
                 -d arch/${ARCH}/boot/$kernel ${initrd} $dtbs \
                 kernel.itb
    else
        echo "TODO: create x86_64 FIT image, now using a raw image"
    fi
}

create_tmpdir()
{
    rm -rf ./tmpdir && mkdir ./tmpdir
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
    umount "$CB_SETUP_STORAGE"* > /dev/null 2>&1 || true

    # Clear the partition table
    sgdisk -Z "$CB_SETUP_STORAGE"

    # Create the boot partition and set it as bootable
    sgdisk -n 1:0:+64M -t 1:7f00 "$CB_SETUP_STORAGE"

    # Set special metadata understood by the Chromebook.  These flags
    # are not standard thus do not have names.  For more details, see
    # the cgpt sources which can be found in vboot_reference chromiumos
    # repository.
    sgdisk -A 1:set:48 -A 1:set:56 "$CB_SETUP_STORAGE"

    # Create and format the root partition
    sgdisk -n 2:0:0 -t 2:7f01 "$CB_SETUP_STORAGE"

    # Tell the system to refresh what it knows about the disk partitions
    partprobe "$CB_SETUP_STORAGE"

    wait_for_partitions_to_appear
    find_partitions_by_id

    mkfs.ext4 -L ROOT-A "$CB_SETUP_STORAGE2"

    echo "Done."
}

find_rootfs()
{
    if [ -z "$CB_SETUP_STORAGE2" ]; then
        find_partitions_by_id
    fi
    ROOTFS_DIR="$(findmnt -n -o TARGET --source $CB_SETUP_STORAGE2)"
}

cmd_mount_rootfs()
{
    # Skip this command if is not a media device.
    if ! $storage_is_media_device; then return 0; fi

    find_partitions_by_id

    echo "Mounting rootfs partition..."

    udisksctl mount -b "$CB_SETUP_STORAGE2" > /dev/null 2>&1 || true
    find_rootfs

    # Verify that the disk is mounted, otherwise exit
    if [ -z "$ROOTFS_DIR" ]; then exit 1; fi

    echo "Done."
}

cmd_setup_rootfs()
{
    cmd_setup_fedora_rootfs
}

cmd_get_kernel()
{
    local tag

    echo "Creating initial git repository if not already present..."

    # 1. Create initial git repository if not already present
    # 2. Checkout the latest release tagged
    [ -d ${CB_KERNEL_PATH} ] || {
        git clone "$KERNEL_URL" ${CB_KERNEL_PATH}
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
    if [ "$ARCH" == "arm64" ]; then
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
    make W=1 "$(jopt)"

    create_fit_image

    cd - > /dev/null

    echo "Done."
}

cmd_deploy_kernel_modules()
{
    echo "Deploy the kernel modules on the rootfs..."

    cd ${CB_KERNEL_PATH}

    # Install the kernel modules on the rootfs
    make modules_install INSTALL_MOD_PATH=$ROOTFS_DIR

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
    local extra_kparams=$EXTRA_KPARAMS

    echo "Sign the kernels to boot with Chrome OS devices..."

    case "$ARCH" in
        arm64)
            arch="arm"
            bootloader="boot_params"
            vmlinuz="$CB_KERNEL_PATH/kernel.itb"
            ;;
        x86_64)
            arch="x86"
            [ -f ./bootstub/bootstub.efi ] || cmd_build_bootstub
            bootloader="./bootstub/bootstub.efi"
            vmlinuz="$CB_KERNEL_PATH/arch/x86/boot/bzImage"
            extra_kparams="${extra_kparams} tpm_tis.force=1 tpm_tis.interrupts=0"
            ;;
        *)
            echo "Unsupported vboot architecture"
            exit 1
            ;;
    esac

    # When using UUIDs, PARTUUID, which is stored in the partition table IS the only way that is
    # available at boot time. `root=LABEL=` and `root=UUID=` only works with an initramfs that
    # fetches these identifiers. Ideally we should have here `root=PARTUUID=%U/PARTNROFF=1` where
    # %U is passed by the bootloader, but, as dracut doesn't support the PARTNROFF we stick on the
    # PARTUUID of the rootfs partition.
    echo "root=PARTUUID=$(lsblk -n -o PARTUUID ${CB_SETUP_STORAGE2}) rootwait rw ${extra_kparams}" > boot_params
    vbutil_kernel --pack $CB_KERNEL_PATH/kernel.vboot \
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
        dd if=$CB_KERNEL_PATH/kernel.vboot of="$boot" bs=4M
    else
        if [ "$ARCH" != "x86_64" ]; then
            cp -av $CB_KERNEL_PATH/kernel.itb "$ROOTFS_DIR/boot"
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

cmd_mount_fedora_rootfs()
{
    local loopdev
    local image
    local btrfs

    image=$(basename $IMAGE)
    loopdev="$(losetup --show -fP $IMAGE)"
    btrfs="${image/raw/btrfs}"
    dd if="${loopdev}p3" of="/var/tmp/$btrfs" conv=fsync status=progress
    losetup -d "$loopdev"
    create_tmpdir
    mount "/var/tmp/$btrfs" ./tmpdir
    sleep 3
}

cmd_umount_fedora_rootfs()
{
    umount ./tmpdir
    rm -rf ./tmpdir
}

# -----------------------------------------------------------------------------
# Experimental: Create Fedora images for Chromebooks
cmd_setup_fedora_rootfs()
{
    echo "Disable SELINUX"
    sed -i 's/SELINUX=enforcing/SELINUX=permissive/' ./tmpdir/root/etc/selinux/config

    echo "Removing the root password"
    sed -i 's/root:!locked:/root:/' ./tmpdir/root/etc/shadow
    sed -i 's/root:x:/root::/' ./tmpdir/root/etc/passwd

    echo "modifying fstab"
    sed -i '1,14s/^[^#]/# &/g' ./tmpdir/root/etc/fstab
    sed -i \
    -e '/home/s/home//' \
    -e '/home/s/btrfs/ext4/' \
    -e 's/subvol=home,compress=zstd:1/defaults/' ./tmpdir/root/etc/fstab

    # Insert the Kernel update script
    echo "Inserting Kernel Update script"
    chmod 777 scripts/96-chromebook.install
    cp scripts/96-chromebook.install ./tmpdir/root/usr/lib/kernel/install.d/

    # Copy the ROOTFS to media
    echo "copying ROOTFS to partition"
    cp -ar "./tmpdir/root/"* "$ROOTFS_DIR"

    echo "Done."
}

cmd_setup_copr_fedora_kernel()
{
    # Download a known kernel that works for Chromebooks
    [ -f kernel-core-${PKGVERSION}.rpm ] || curl -OL ${COPR}/kernel-core-${PKGVERSION}.rpm
    [ -f kernel-modules-${PKGVERSION}.rpm ] || curl -OL ${COPR}/kernel-modules-${PKGVERSION}.rpm
    [ -f kernel-modules-core-${PKGVERSION}.rpm ] || curl -OL ${COPR}/kernel-modules-core-${PKGVERSION}.rpm

    rpm2cpio kernel-core-${PKGVERSION}.rpm | cpio -idmv
    rpm2cpio kernel-modules-${PKGVERSION}.rpm | cpio -idmv
    rpm2cpio kernel-modules-core-${PKGVERSION}.rpm | cpio -idmv

    sudo cp -a ./lib/modules//${PKGVERSION}/vmlinuz vmlinuz-${PKGVERSION}
    sudo cp -ar ./usr/* "$ROOTFS_DIR"/usr
    sudo cp -ar ./lib/* "$ROOTFS_DIR"/lib
}

cmd_setup_fedora_kernel()
{
    local kernel_version
    local image_path
    local binfmt_entry
    local binfmt_chroot

    if [ -z "$IMAGE" ]; then
        echo "Error: a Fedora image was not set."
        exit 1
    fi

    image_path="$(readlink -f $IMAGE)"

    # Extract and copy the kernel packages to the rootfs
    create_tmpdir && pushd ./tmpdir

    # Extract kernel and initramfs images if were not provided
    if [ -z "$KERNEL" ] && [ -z "$INITRD" ]; then
        if [ -z "$COPR" ]; then
            LIBGUESTFS_BACKEND=direct virt-builder --get-kernel "$image_path" -o .
        else
            cmd_setup_copr_fedora_kernel
        fi
    fi

    kernel_version="$(ls vmlinuz-* | sed -e 's/vmlinuz-//')"

    popd && rm -rf ./tmpdir

    if [ ! -d "$ROOTFS_DIR/lib/modules/$kernel_version" ]; then
	cmd_mount_fedora_rootfs
	cp -a ./tmpdir/root/lib/modules/$kernel_version "$ROOTFS_DIR/lib/modules/"
	cmd_umount_fedora_rootfs
    fi

    create_tmpdir && pushd ./tmpdir

    # Generate modules.dep and map files, so modules autoload on first boot
    if [ -z "$ROOTFS_DIR" ]; then
        find_rootfs
    fi
    depmod -b "$ROOTFS_DIR" "$kernel_version"

    # Create a directory tree similar to the kernel source tree so we can reuse some functions
    # like cmd_build_vboot and cmd_deploy_vboot
    mkdir -p arch/arm64/boot/dts

    if vmlinuz_is_an_efi_application "$ROOTFS_DIR/lib/modules/$kernel_version/vmlinuz"; then
        ensure_command unzboot unzboot
        unzboot "$ROOTFS_DIR/lib/modules/$kernel_version/vmlinuz" arch/arm64/boot/Image
    else
        cp "$ROOTFS_DIR/lib/modules/$kernel_version/vmlinuz" arch/arm64/boot/Image.gz
        gunzip arch/arm64/boot/Image.gz
    fi;

    cp -fr "$ROOTFS_DIR/lib/modules/$kernel_version/dtb"/* arch/arm64/boot/dts/

    if [ -z "$INITRD" ]; then
        # Generate initramfs for the kernel
        # chroot into qemu-aarch-static to generate initramfs for aarch64
        ensure_command qemu-aarch64-static qemu-user-static-aarch64 qemu-user-static
        # shellcheck disable=SC2010
        binfmt_entry=$(ls /proc/sys/fs/binfmt_misc/ | grep aarch64 | head -1)
        if [ -z "$binfmt_entry" ]; then
            echo 'No aarch64 support found in /proc/sys/fs/binfmt_misc/.'
            echo 'Make sure binfmt-misc support is enabled in kernel and aarch64 emulator package'
            echo 'is present (e.g. qemu-user-static-aarch64 on Fedora, qemu-user-static on Debian).'
            exit 1
        fi
        binfmt_chroot="$ROOTFS_DIR$(sed -n -e '/^interpreter /s/^interpreter //p' /proc/sys/fs/binfmt_misc/"$binfmt_entry")"
        mkdir -p "$(dirname $binfmt_chroot)"
        cp "$(which qemu-aarch64-static)" "$binfmt_chroot"
        mount -t sysfs sysfs "$ROOTFS_DIR/sys"
        mount -t proc proc "$ROOTFS_DIR/proc"
        mount -t tmpfs tmpfs "$ROOTFS_DIR/tmp"
        mount -t devtmpfs devtmpfs "$ROOTFS_DIR/dev"
        cat << EOF | chroot "/var$ROOTFS_DIR" /bin/bash
        export PATH=/usr/bin:/usr/sbin
        dracut --force -v --add-drivers "ulpi usb-storage phy-qcom-usb-hs-28nm \
        phy-qcom-usb-ss ocmem dwc3 dwc3-of-simple dwc3-pci ehci-platform xhci-plat-hcd \
        i2c-qcom-geni i2c-qup icc-osm-l3 qcom-spmi-pmic phy-qcom-qmp-combo phy-qcom-qusb2 \
        phy-qcom-usb-hs qcom_aoss qcom-apcs-ipc-mailbox llcc-qcom nvmem_qfprom smem \
        smp2p dwc3-qcom onboard_usb_hub mmc_block sdhci_msm \
        " /boot/initramfs-$kernel_version.img --kver $kernel_version --kmoddir /lib/modules/$kernel_version
EOF
        cp "$ROOTFS_DIR/boot/initramfs-$kernel_version.img" arch/arm64/boot/
    fi
    create_fit_image

    popd

    export CB_KERNEL_PATH=./tmpdir
    cmd_build_vboot
    cmd_deploy_vboot

    rm -rf ./tmpdir
    if [ -z "$INITRD" ]; then
        umount tmpfs
        umount devtmpfs
        umount proc
        umount sysfs
    fi
}

cmd_get_fedora_image()
{
    if [ -z "$IMAGE" ]; then
        fedora_image=$(curl -s -L $GETFEDORA | sed "s/>/>\n/g" | grep -o 'href=".*raw.xz">' | sed -e 's/href="//' -e 's/[>,", ].*//')
        IMAGE=$(basename -s .xz $fedora_image)
        if [ ! -f "$fedora_image" ] && [ ! -f "$IMAGE" ]; then
            echo "Downloading image $fedora_image"
            curl -OL $GETFEDORA/$fedora_image
        fi
        if [ ! -f "$IMAGE" ]; then
            echo "Decompress .xz image"
            unxz "$fedora_image"
        fi
    fi
}

cmd_deploy_fedora_kernel()
{
    if [ ! -f "$IMAGE" ] && [ "$IMAGE" != "" ]; then
        echo "Error: $IMAGE not found please choose an existing image."
        exit 1
    fi

    CB_DISTRO=fedora

    cmd_get_fedora_image
    cmd_mount_rootfs
    cmd_setup_fedora_kernel
    cmd_eject_storage
}

cmd_deploy_fedora()
{
    if [ ! -f "$IMAGE" ] && [ "$IMAGE" != "" ]; then
        echo "Error: $IMAGE not found please choose an existing image."
        exit 1
    fi

    CB_DISTRO=fedora

    cmd_get_fedora_image
    cmd_format_storage
    cmd_mount_rootfs
    cmd_mount_fedora_rootfs
    cmd_setup_fedora_rootfs
    cmd_umount_fedora_rootfs
    cmd_setup_fedora_kernel
    cmd_eject_storage
}

cmd_do_everything()
{
    CB_DISTRO=fedora

    cmd_get_fedora_image
    cmd_format_storage
    cmd_mount_rootfs
    cmd_setup_rootfs
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

# Ensure sudo user
if [ "$(whoami)" != "root" ]; then
    echo "Error: This script requires 'sudo' privileges in order to write to disk & mount media."
    exit 1
fi

if grep -qi fedora /etc/os-release; then
    pkg_mgr="dnf"
else
    pkg_mgr="apt"
fi

# These commands are required
ensure_command which which
ensure_command bc bc
ensure_command curl curl
ensure_command findmnt util-linux
ensure_command realpath coreutils
ensure_command sgdisk gdisk
ensure_command lz4 lz4
ensure_command mkfs.ext4 e2fsprogs
ensure_command mkimage uboot-tools u-boot-tools
ensure_command udisksctl udisks2
ensure_command vbutil_kernel vboot-utils
ensure_command virt-builder guestfs-tools

# Run the command if it's valid, otherwise abort
type cmd_"$cmd" > /dev/null 2>&1 || print_usage_exit
cmd_"$cmd" "$@"

exit 0
