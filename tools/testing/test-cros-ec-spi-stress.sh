#!/bin/sh

. lava-test-report

TEST_CASE_ID="$1"

if [ -z "${TEST_CASE_ID}" ]; then
	echo "Usage: $0 <test-case-id>"
	exit 1
fi

# Error string to check in dmesg
ERRORS="Command xfer error"
# Power supply sysfs path
SYSFS="/sys/class/power_supply"

# charge_now path for different boards
for compatible in $(tr "\0" "\n" < /proc/device-tree/compatible); do
	case "${compatible}" in
		"google,kevin")
			CHARGE_NOW="sbs-9-000b/charge_now"
			;;
		"google,peach")
			CHARGE_NOW="sbs-20-000b/charge_now"
			;;
		"google,veyron-jaq")
			CHARGE_NOW="sbs-20-000b/charge_now"
			;;
		"google,veyron-minnie")
			CHARGE_NOW="bq27500-0/charge_now"
			;;
		*)
			;;
	esac
done

# If charge_now path is not set skip the test
if [ -z ${CHARGE_NOW} ]; then
	test_report_exit skip
fi

# Interrupt handler to exit the infinite loop
abort=0
inthandler()
{
	abort=1
}

trap inthandler INT QUIT KILL TSTP TERM

# Launch some processes to stress the cpu
md5sum /dev/zero &
md5sum /dev/zero &
md5sum /dev/zero &
md5sum /dev/zero &
# Clear the ring buffer
dmesg -C

while [ ${abort} -eq 0 ]
do
	cat ${SYSFS}/${CHARGE_NOW} > /dev/null
	dmesg -c | grep "${ERRORS}"
	if [ $? -eq 0 ]; then
		# Kill md5sum processes
		kill -9 $(pidof md5sum)
		test_report_exit fail
	fi
done

kill -9 $(pidof md5sum)

test_report_exit pass

