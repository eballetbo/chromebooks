#!/usr/bin/env bash

# Exit on error. Append "|| true" if you expect an error.
set -e

abort=0

inthandler()
{
	echo "Aborting ..."
	abort=1
}

trap inthandler INT QUIT KILL TSTP TERM

# Ports for Samsung Chromebook Plus
ports=("usb@fe800000" "usb@fe900000")
usbdir="/sys/bus/platform/drivers/dwc3-of-simple"

while [ ${abort} -eq 0 ]
do
	for p in ${ports[@]}; do
		echo $p > ${usbdir}/unbind

		to=$(echo "scale=2;$(($RANDOM % 50))/100" | bc -q)
		sleep ${to}

		echo $p > ${usbdir}/bind
	done
done
