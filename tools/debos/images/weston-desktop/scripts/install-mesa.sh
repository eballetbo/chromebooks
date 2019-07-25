#!/bin/sh

set -e

# Create the source directory
mkdir -p /usr/local/src && cd /usr/local/src

# Clone the latest version
git clone https://gitlab.freedesktop.org/mesa/mesa -b master

# Go to the application directory and build
cd mesa

meson build/ -Ddri-drivers= -Dvulkan-drivers= -Dgallium-drivers=panfrost,kmsro -Dlibunwind=false
ninja -C build/

# Install mesa to the default directory
ninja -C build/ install

