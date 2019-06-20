=======================================
Samsung Chromebook Plus Demo (scp-demo)
=======================================

The Samsung Chromebook Plus (kevin) is a convertible touchscreen laptop powered by an ARMv8 Rockchip RK3399 hexa-core processor and 4GB RAM, measuring 11.04" x 8.72" x 0.55" and weighing 2.38 lbs.

Features:

* Rockchip RK3399 (OP1) dual-core 2.0GHz Cortex-A72 and quad-core 1.4GHz Cortex-A53 processor
* 4GB LPDDR3 RAM
* 12.3" 2400x1600 LED display
* Mali T860MP4 GPU
* 32GB eMMC
* 5140 mAh battery
* 2x USB 3.0 Type-C ports
* Built-in stylus

The purpose of this demo is show current support in mainline for Samsung Chromebook Plus. The demo runs a `Debian` based image with Weston and accelerated graphics using Panfrost.

The `Debian` images are assembled using the [debos](https://github.com/go-debos/debos) utility, which uses the `Debian` package feed beneath. Stuff not available in official `Debian` packages will be built from sources or downloaded into the final image.

The Debian way to build the demo rootfs
=======================================

To install [debos](https://github.com/go-debos/debos) you can do the following steps:

.. code-block:: sh

  $ sudo apt install golang git libglib2.0-dev libostree-dev qemu-system-x86 qemu-user-static debootstrap systemd-container xz-utils bmap-tools
  $ export GOPATH=`pwd`/gocode
  $ go get -u github.com/go-debos/debos/cmd/debos

First, make sure you have KVM installed:

.. code-block:: sh

  $ sudo apt install qemu-kvm ovmf


Now that that’s done, let’s create the images, run:

.. code-block:: sh

  $ $GOPATH/bin/debos -m 4G tools/debos/images/weston/scp-demo.yaml

Will create the following output:

- debian-scp-demo-sid-arm64.tar.gz, a tarball with the debian weston based filesystem.

The Docker way to build the demo rootfs
=======================================

**NOT TESTED YET**

This is really simple as an official container is provided for it:

.. code-block:: sh

  $ docker pull godebos/debos

To build the image run:

.. code-block:: sh

  $ docker run --rm --interactive --tty --device /dev/kvm --user $(id -u) --workdir /recipes --mount "type=bind,source=$(pwd),destination=/recipes" --security-opt label=disable godebos/debos tools/debos/images/weston/scp-demo.yaml

Quick steps to create a SD-card
===============================

.. code-block:: sh

  $ ./chromebook-setup.sh do_everything --architecture=arm64 --storage=/dev/mmcblkX
  $ 

Connect the Wiimote
===================

First you need to make sure to load the uinput module:

.. code-block:: sh

  $ modprobe uinput

Thanks to cwiid you can scan for your Wiimote now:

.. code-block:: sh

  (press the 1 and 2 buttons on your Wiimote)
  $ bluetoothctl scan on
  Scanning ...
       <MAC address>       Nintendo RVL-CNT-01

The Wiimote can act as a regular input device like a mouse using wminput, simply run:

.. code-block:: sh

  $ wminput -w

Tips and tricks
===============

For some reason the ethernet interface (through a docking USB-C) is down, to enable it run:

.. code-block:: sh

  $ ip link set enx0050b6213e94 up

