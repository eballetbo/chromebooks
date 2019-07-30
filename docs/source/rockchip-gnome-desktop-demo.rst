===================
Gnome Rockchip Demo
===================

The purpose of this demo is show current support in mainline for different Rockchip boards. The demo runs a `Debian` based image with Gnome and accelerated graphics using Panfrost.

The `Debian` images are assembled using the `debos <http://github.com/go-debos/debos>`_ utility, which uses the `Debian` package feed beneath. Stuff not available in official `Debian` packages will be built from sources or downloaded into the final image.

Supported and tested hardware
=============================

.. include:: chromebooks/samsung-chromebook-plus.rst

The Debian way to build the demo rootfs
=======================================

.. include:: install-debos-on-debian.rst

Now that debos is installed, let’s create the demos images, run:

.. code-block:: sh

  Export the architecture of your device:

  $ export architecture=arm64

  And then run:

  $ $GOPATH/bin/debos -m 4G -t architecture:$architecture tools/debos/images/gnome-desktop/gnome-desktop.yaml

Will create the following output:

- debian-gnome-desktop-sid-$architecture.tar.gz, a tarball with the debian Gnome based filesystem.

**IMPORTANT**: Actually this step will fail unless you have the new mesa packages locally. I am still creating and testing new versions. If you're interested in get the latest version I built of the mesa packages I can send to you, just contact me.

After that, run:

.. code-block:: sh

  $ $GOPATH/bin/debos -m 4G -t architecture:$architecture tools/debos/images/gnome-desktop/chromebook-image.yaml

Will create the following output:

- debian-gnome-desktop-sid-$architecture.img.gz, a gz-compressed image file for a Chromebook.
- debian-gnome-desktop-sid-$architecture.img.gz.md5, the image checksum.
- debian-gnome-desktop-sid-$architecture.img.bmap, a bitmap summary for faster flashing via bmaptools.

To flash it, assuming your SD card is /dev/mmcblk0, use:

.. code-block:: sh

  $ bmaptool copy debian-gnome-desktop-sid-$architecture.img.gz /dev/mmcblk0

The bmap file is automatically looked for in the current directory.

Note that the credentials to login are debian:debian.

Appendix
========

The Docker way to build the demo rootfs
---------------------------------------

.. include:: install-debos-on-docker.rst


Extend the rootfs partition to fill available space
---------------------------------------------------

.. include:: extend-partition-to-fill-available-space.rst



