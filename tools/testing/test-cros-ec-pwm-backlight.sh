#!/bin/sh

. lava-test-report

TEST_CASE_ID="$1"

if [ -z "${TEST_CASE_ID}" ]; then
	echo "Usage: $0 <test-case-id>"
	exit 1
fi

echo $(expr $(cat /sys/class/backlight/backlight/max_brightness) / 2) > /sys/class/backlight/backlight/brightness

if [ $(cat /sys/kernel/debug/pwm | grep backlight | sed 's/.*duty: //' | cut -d ' ' -f1) -eq "0" ]
then
	test_report_exit fail
fi

test_report_exit pass

