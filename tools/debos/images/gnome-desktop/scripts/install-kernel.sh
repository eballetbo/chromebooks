#!/bin/sh

set -e

if [ -z "${ROOTDIR}" ]; then
  echo "ROOTDIR not given"
  exit 1
fi

# Download kernel image from kernelCI storage
wget https://storage.kernelci.org/mainline/master/v5.3-rc1/arm64/defconfig/gcc-8/Image
wget https://storage.kernelci.org/mainline/master/v5.3-rc1/arm64/defconfig/gcc-8/dtbs/rockchip/rk3399-gru-kevin.dtb
wget https://storage.kernelci.org/mainline/master/v5.3-rc1/arm64/defconfig/gcc-8/modules.tar.xz

tar xvf modules.tar.xz --strip 2 -C ${ROOTDIR}/lib

# Compress the image
lz4 Image Image.lz4

# Create the FIT image
mkimage -D "-I dts -O dtb -p 2048" -f auto -A arm64 -O linux -T kernel -C lz4 -a 0 \
        -d Image.lz4 -b rk3399-gru-kevin.dtb kernel.itb

# And sign the image (including the kernel boot parameters)
echo "root=PARTUUID=%U/PARTNROFF=1 rootwait rw" > boot_params
vbutil_kernel --pack kernel.vboot \
              --keyblock /usr/share/vboot/devkeys/kernel.keyblock \
              --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
              --version 1 --config boot_params \
              --bootloader boot_params \
              --vmlinuz kernel.itb \
              --arch arm

