#!/bin/sh

set -e

storage_kernelci_org="https://storage.kernelci.org/mainline/master/v5.4"
architecture=""
compression=""
kernel=""
dtbs=""

if [ -z "${ROOTDIR}" ]; then
  echo "ROOTDIR not given"
  exit 1
fi

# Download kernel image from kernelCI storage
if [ "${1}" = "arm64" ]; then
  boards="rk3399-gru-kevin.dtb rk3399-gru-scarlet-inx.dtb"
  architecture="arm64"

  wget ${storage_kernelci_org}/arm64/defconfig/gcc-8/Image

  for board in ${boards}; do
    wget ${storage_kernelci_org}/arm64/defconfig/gcc-8/dtbs/rockchip/${board}
  done

  wget ${storage_kernelci_org}/arm64/defconfig/gcc-8/modules.tar.xz

  kernel="Image.lz4"
  compression="lz4"
  # Compress image
  lz4 Image Image.lz4

  dtbs="-b rk3399-gru-kevin.dtb \
        -b rk3399-gru-scarlet-inx.dtb"

elif [ "${1}" = "armhf" ]; then
  boards="rk3288-veyron-minnie.dtb rk3288-veyron-jerry.dtb"
  architecture="arm"

  wget ${storage_kernelci_org}/arm/multi_v7_defconfig/gcc-8/zImage

  for board in ${boards}; do
    wget ${storage_kernelci_org}/arm/multi_v7_defconfig/gcc-8/dtbs/${board}
  done

  wget ${storage_kernelci_org}/arm/multi_v7_defconfig/gcc-8/modules.tar.xz

  kernel="zImage"
  compression="none"
  dtbs="-b rk3288-veyron-minnie.dtb \
        -b rk3288-veyron-jerry.dtb"

else
  echo "${1} is a non-supported architecture, possible values are: armhf, arm64."
  exit 1
fi

# Create FIT image
mkimage -D "-I dts -O dtb -p 2048" -f auto -A ${architecture} -O linux -T kernel -C ${compression} -a 0 \
        -d ${kernel} ${dtbs} kernel.itb

# Install modules to the image
tar xvf modules.tar.xz --strip 2 -C ${ROOTDIR}/lib

# And sign the image (including the kernel boot parameters)
echo "root=PARTUUID=%U/PARTNROFF=1 rootwait rw" > boot_params
vbutil_kernel --pack kernel.vboot \
              --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
              --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
              --version 1 --config boot_params \
              --bootloader boot_params \
              --vmlinuz kernel.itb \
              --arch arm

