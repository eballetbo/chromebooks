# Chromebook developer tool
These instructions will create a dual-booting environment where you can
switch between booting Debian and the stock ChromeOS. No changes are made
to the internal eMMC drive, and your new Debian install will run
completely from external storage. This is the recommended setup for those
that just want to take a test drive, or don't want to give up ChromeOS.

You must be running the latest ChromeOS prior to installation.

The following Chromebook have been tested with this tool.
- ASUS Chromebook Flip C100PA (C100PA - arm)
- CTL J2 Chromebook for Education (NBCJ2 - arm)
- Samsung Chromebook Plus (XE513C24 -arm64)

## Switch to developer mode
1. Turn off the laptop.
2. To invoke Recovery mode, you hold down the ESC and Refresh keys and
   poke the Power button.
3. At the Recovery screen press Ctrl-D (there's no prompt - you have to
   know to do it).
4. Confirm switching to developer mode by pressing enter, and the laptop
   will reboot and reset the system. This takes about 10-15 minutes.

Note: After enabling developer mode, you will need to press Ctrl-D each
      time you boot, or wait 30 seconds to continue booting.

## Enable booting from external storage
1. After booting into developer mode, hold Ctrl and Alt and poke the F2
   key. This will open up the developer console.
2. Type root to the login screen.
3. Then type this to enable USB booting:
```sh
$ enable_dev_usb_boot
```
4. Reboot the system to allow the change to take effect.

## Create a USB or SD for dual booting
```sh
$ ./chromebook-setup.sh help
```
For example, to create bootable SD card for the Samsung Chromebook Plus (arm64):
```sh
$ ./chromebook-setup.sh do_everything --architecture=arm64 --storage=/dev/sdX
```

## Appendix
### How to create a Debian image for Chromebooks
You can build the Chromebook image for a specific suite and architecture like this:
```sh
$ debos -t arch:"arm64" debos/debimage.yaml
```
The images can be built for different architectures (only armhf and arm64 are complete)
