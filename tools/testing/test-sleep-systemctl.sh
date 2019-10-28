#!/bin/sh

. lava-test-report

TEST_CASE_ID="${1}"
# Number of suspend/resume interations
ITERATIONS=${2:-10}

if [ -z "${TEST_CASE_ID}" ]; then
        echo "Usage: ${0} <test-case-id> [iterations]"
        exit 1
fi

# Clear the ring buffer
dmesg -C

for i in $(seq 1 ${ITERATIONS}); do
	TEST_CASE_ID="${1}-${i}"
	# This will trigger activation of the special target unit
	# suspend.target. This command is asynchronous, and will
	# return after the suspend operation.
	#
	# NOTE: Internally, this service will echo a string like
	# "mem" into /sys/power/state, to trigger the actual system
	# suspend. What exactly is written where can be configured
	# in the "[Sleep]" section of /etc/systemd/sleep.conf. But,
	# for the test case I actually testing echoing "mem" just
	# works, whereas, if I use the "systemctl suspend" command I
	# can reproduce the issue.
	systemctl suspend
        # Wait for system to suspend and also wait for errors to appear
	sleep 10
        # Press a key to wake-up and look for errors in dmesg
        dmesg -c -l err | grep ' '
        if [ $? -eq 0 ]; then
                test_report_exit fail
	else
		test_report pass
	fi
done

exit 0
