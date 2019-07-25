**NOT TESTED YET**

This is really simple as an official container is provided for it:

.. code-block:: sh

  $ docker pull godebos/debos

To build the image run:

.. code-block:: sh

  $ docker run --rm --interactive --tty --device /dev/kvm --user $(id -u) --workdir /recipes --mount "type=bind,source=$(pwd),destination=/recipes" --security-opt label=disable godebos/debos <debos-image.yaml>
