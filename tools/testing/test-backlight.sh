#!/bin/sh

sysfs=/sys/class/backlight/backlight
max_brightness=$(cat $sysfs/max_brightness)

for i in `seq 0 $max_brightness`; do
     echo $i > $sysfs/brightness
     sleep 0.001
done

for i in `seq $max_brightness -1 0`; do
     echo $i > $sysfs/brightness
     sleep 0.001
done

for i in `seq 0 $max_brightness`; do
     echo $i > $sysfs/brightness
     sleep 0.001
done

