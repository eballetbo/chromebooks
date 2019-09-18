#!/bin/sh

set -e

ARCH=${1}
VERSION="19.3+git20190913.9db06a53"

apt-get install -y libllvm8

# Create a packages directory
mkdir packages && cd packages
# and download the mesa packages
curl -O https://people.collabora.com/~eballetbo/debian/packages/mesa-${VERSION}_${ARCH}.tar.xz
# the tarball contains all the mesa debian packages
tar xf mesa-${VERSION}_${ARCH}.tar.xz
# but we only install the required to have panfrost working
dpkg -i libgbm1_${VERSION}_*.deb
dpkg -i libegl1-mesa_${VERSION}_*.deb
dpkg -i libegl-mesa0_${VERSION}_*.deb
dpkg -i libgl1-mesa-dri_${VERSION}_*.deb
dpkg -i libglapi-mesa_${VERSION}_*.deb
dpkg -i libglx-mesa0_${VERSION}_*.deb

