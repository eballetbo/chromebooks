What you need to do is to run growpart against you physical disk and partition.

For example your disk is /dev/mmcblk0 and your partition is 2. What growpart does is actually extending the size of your partition to the maximum allowed physical disk size.

You can run below command:

.. code-block:: sh

  $ growpart /dev/mmcblk0 2

Once it finish you will see growpart has extend your partition table to the maximum available disk size.

Now, you need to reboot your machine. When the machine comes live again, you can run resize2fs command to extend the filesystem. Below is the sample command.

.. code-block:: sh

  $ resize2fs /dev/mmcblk0p2

