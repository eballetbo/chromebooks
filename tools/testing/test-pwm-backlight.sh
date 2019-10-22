#!/bin/sh

echo $(expr $(cat /sys/class/backlight/backlight/max_brightness) / 2) > /sys/class/backlight/backlight/brightness

if [ $(cat /sys/kernel/debug/pwm | grep backlight | sed 's/.*duty: //' | cut -d ' ' -f1) -eq "0" ]
then
        echo "FAIL"
else
        echo "PASS"
fi

exit 0
