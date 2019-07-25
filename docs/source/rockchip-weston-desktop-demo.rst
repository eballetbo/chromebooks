====================
Weston Rockchip Demo
====================

The purpose of this demo is show current support in mainline for different Rockchip boards. The demo runs a `Debian` based image with Weston and accelerated graphics using Panfrost.

The `Debian` images are assembled using the `debos <http://github.com/go-debos/debos>`_ utility, which uses the `Debian` package feed beneath. Stuff not available in official `Debian` packages will be built from sources or downloaded into the final image.

Supported and tested hardware
=============================

Samsung Chromebook Plus (kevin)
-------------------------------

.. include:: chromebooks/samsung-chromebook-plus.rst

ASUS Chromebook Flip C100P (veyron_minnie)
------------------------------------------

.. include:: chromebooks/asus-chromebook-flip-c100p.rst

The Debian way to build the demo rootfs
=======================================

.. include:: install-debos-on-debian.rst

Now that debos is installed, let’s create the demos images, run:

.. code-block:: sh

  Export the architecture of your device:

  $ export architecture=arm64
  or
  $ export architecture=armhf

  And then run:
  $ $GOPATH/bin/debos -m 4G -t architecture:$architecture tools/debos/images/weston-desktop/weston-desktop.yaml

Will create the following output:

- debian-weston-desktop-sid-$architecture.tar.gz, a tarball with the debian weston based filesystem.


Quick steps to create a SD-card
===============================

.. code-block:: sh

  $ ./chromebook-setup.sh do_everything --architecture=<arm64|arm> --storage=/dev/mmcblkX


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


Known issues
============

1. Ethernet is down by default
------------------------------

For some reason the ethernet interface (through a docking USB-C) is down, to enable it run:

.. code-block:: sh

  $ ip link set enx0050b6213e94 up


Appendix
========

The Docker way to build the demo rootfs
---------------------------------------

.. include:: install-debos-on-docker.rst

