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

# SPI bus and CS where the CrOS EC is connected on Samsung Chromebook Plus
spidev="spi2.0"
sysfs="/sys/bus/spi/drivers/cros-ec-spi"

while [ ${abort} -eq 0 ]
do
	echo ${spidev} > ${sysfs}/unbind

	to=$(echo "scale=2;$(($RANDOM % 50))/100" | bc -q)
	sleep ${to}

	echo ${spidev} > ${sysfs}/bind
done
