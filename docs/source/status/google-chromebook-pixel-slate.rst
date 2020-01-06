=============================
Google Chromebook Pixel Slate
=============================

+------------+-----------------------+
| Board      | Nocturne              |
+------------+-----------------------+
| SoC        | Intel i5              |
+------------+-----------------------+
| RAM        | 8GB                   |
+------------+-----------------------+
| Firmware   | Coreboot              |
+------------+-----------------------+
| Boot media | eMMC or USB           |
+------------+-----------------------+

Kernel Status Report
====================

+----------------------------------------------------------+
| Kernel version: 5.4.8                                    |
+---------------------+-------------------+----------------+
| Component           | Model             | Status         |
+---------------------+-------------------+----------------+
| CPU                 | Intel i5          | Works          |
+---------------------+-------------------+----------------+
| GPU                 | Intel UHD         | Works          |
|                     | Graphics 615      |                |
+---------------------+-------------------+----------------+
| USB type C          |                   | Works          |
+---------------------+-------------------+----------------+
| Display             | 12.3" @ 3000x2000 | Works          |
+---------------------+-------------------+----------------+
| WiFi                |                   | Works          |
+---------------------+-------------------+----------------+
| Bluetooth           |                   | Fail           |
+---------------------+-------------------+----------------+
| Touchpad            |                   | Fail           |
+---------------------+-------------------+----------------+
| Touscreen           |                   | Works          |
+---------------------+-------------------+----------------+
| Front Camera        |                   | Fail           |
+---------------------+-------------------+----------------+
| Back Camera         |                   | Fail           |
+---------------------+-------------------+----------------+
| Embedded Controller | Google CrOS EC    | Works          |
+---------------------+-------------------+----------------+
|                     | Speaker           | Fail           |
|  Audio              +-------------------+----------------+
|                     | Headphone         | Untested       |
+---------------------+-------------------+----------------+

Notes:
======

camera:
-------

The camera seems to work but are not fully tested.
Nocturne uses INTEL IPU3 to get data form camera sensors.
In order to test it, we can use libcamera.

Download git camera tool:

```
git clone git://linuxtv.org/libcamera.git
cd libcamera
meson build
ninja -C build install
```

You should see 2 devices, imx355 and imx319 with 'cam -l'

You can get data from sensors:

```
cam -c "imx319 9-0010 0" -C --file="/tmp/libcamframe#.data" -s width=1280,height=720
or
cam -c "imx355 10-001a 1" -C --file="/tmp/libcamframe#.data" -s width=1280,height=720
```

Next step is to use IMGU device to transform raw data to viewable pictures.
This can be done using v4l2n tool available here: https://github.com/intel/nvt

