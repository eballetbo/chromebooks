=============================
Google Chromebook Pixel Slate
=============================

+------------+-----------------------+
| Board      | Nocturne              |
+------------+-----------------------+
| SoC        | Intel Celeron/m3/i5/i7              |
+------------+-----------------------+
| RAM        | 4GB/8GB/16GB                |
+------------+-----------------------+
| Firmware   | Coreboot              |
+------------+-----------------------+
| Boot media | eMMC or USB           |
+------------+-----------------------+

Kernel Status Report
====================

+------------------------------------------------------------+
| Kernel version: 5.12.2 boots (ChromeOS uses 4.4.x)         |
+---------------------+-------------------+------------------+
| Component           | Model             | Status           |
+---------------------+-------------------+------------------+
| CPU                 | Intel i7          | Works            |
+---------------------+-------------------+------------------+
| GPU                 | Intel UHD         | Works            |
|                     | Graphics 615      |                  |
+---------------------+-------------------+------------------+
| USB Type-C          |                   | Works            |
+---------------------+-------------------+------------------+
| Display             | 12.3" @ 3000x2000 | Works            |
+---------------------+-------------------+------------------+
| Display Backlight   | DPCD Backlight    | Works with patch |
+---------------------+-------------------+------------------+
| WiFi                |                   | Works            |
+---------------------+-------------------+------------------+
| Bluetooth           |                   | Fail             |
+---------------------+-------------------+------------------+
| Touchpad            |                   | Works            |
+---------------------+-------------------+------------------+
| Touchscreen         |                   | Works            |
+---------------------+-------------------+------------------+
| Front Camera        |                   | Fail             |
+---------------------+-------------------+------------------+
| Back Camera         |                   | Fail             |
+---------------------+-------------------+------------------+
| Embedded Controller | Google CrOS EC    | Works            |
+---------------------+-------------------+------------------+
|                     | Speaker           | Fail             |
|  Audio              +-------------------+------------------+
|                     | Headphone         | Untested         |
+---------------------+-------------------+------------------+

Notes:
======

Camera:
-------

The camera seems to work but are not fully tested.
Nocturne uses INTEL IPU3 to get data form camera sensors.
In order to test it, we can use libcamera.

Download git camera tool: ::

  git clone git://linuxtv.org/libcamera.git
  cd libcamera
  meson build
  ninja -C build install


You should see 2 devices, imx355 and imx319 with 'cam -l'

You can get data from sensors: ::

  cam -c "imx319 9-0010 0" -C --file="/tmp/libcamframe#.data" -s width=1280,height=720
or ::

  cam -c "imx355 10-001a 1" -C --file="/tmp/libcamframe#.data" -s width=1280,height=720


Next step is to use IMGU device to transform raw data to viewable pictures.
This can be done using v4l2n tool available here: https://github.com/intel/nvt

Display Backlight:
------------------

Works with this patch to mainline kernels (This is for 5.12.x): ::


  diff -Npaur a/drivers/gpu/drm/i915/display/intel_dp_aux_backlight.c b/drivers/gpu/drm/i915/display/intel_dp_aux_backlight.c
  --- a/drivers/gpu/drm/i915/display/intel_dp_aux_backlight.c	2021-05-07 18:57:14.612178675 -0400
  +++ b/drivers/gpu/drm/i915/display/intel_dp_aux_backlight.c	2021-05-07 18:58:15.107279925 -0400
  @@ -593,7 +593,6 @@ intel_dp_aux_supports_vesa_backlight(str
   	 * work just fine using normal PWM controls anyway.
   	 */
   	if (intel_dp->edp_dpcd[1] & DP_EDP_TCON_BACKLIGHT_ADJUSTMENT_CAP &&
  -	    (intel_dp->edp_dpcd[1] & DP_EDP_BACKLIGHT_AUX_ENABLE_CAP) &&
   	    (intel_dp->edp_dpcd[2] & DP_EDP_BACKLIGHT_BRIGHTNESS_AUX_SET_CAP)) {
   		drm_dbg_kms(&i915->drm, "AUX Backlight Control Supported!\n");
   		return true;

Alt-Boot Firmware:
------------------

After building coreboot, you can generate altboot EFI firmware for EFI boot of linux via grub-efi using these steps: ::

  curl -OLf https://www.mrchromebox.tech/files/firmware/full_rom/coreboot_tiano-nocturne-mrchromebox_20210423.rom
  coreboot/util/cbfstool/cbfstool coreboot_tiano-nocturne-mrchromebox_20210423.rom extract -n fallback/payload -m x86 -f cbox-pl
  coreboot/util/cbfstool/cbfstool nocturne.bin create -m x86 -s 0x001C0000
  coreboot/util/cbfstool/cbfstool nocturne.bin add-payload -f cbox-pl -c lzma -n payload
  coreboot/util/cbfstool/cbfstool nocturne.bin print
  dd if=/dev/zero bs=256k count=1 > smmstore
  coreboot/util/cbfstool/cbfstool nocturne.bin add -f smmstore -n "smm store" -t raw
  coreboot/util/cbfstool/cbfstool nocturne.bin print
  
Once you have the nocturne.bin firmware you use the flashrom command (also needs downloading) to install the firmware with a script thus: ::

  #!/bin/bash
  sudo crossystem dev_boot_legacy=1 
  rwlegacy_file=~/firmware/nocturne.bin
  flashromcmd=~/bin/flashrom
  sudo ${flashromcmd} -w -i RW_LEGACY:${rwlegacy_file} -o /tmp/flashrom.log
