To install `debos <http://github.com/go-debos/debos>`_ you can do the following steps:

.. code-block:: sh

  $ sudo apt install golang git libglib2.0-dev libostree-dev qemu-system-x86 qemu-user-static debootstrap systemd-container xz-utils bmap-tools
  $ export GOPATH=`pwd`/gocode
  $ go get -u github.com/go-debos/debos/cmd/debos

First, make sure you have KVM installed:

.. code-block:: sh

  $ sudo apt install qemu-kvm ovmf

  And then run:

  $ $GOPATH/bin/debos -m 4G <debos-image.yaml>
