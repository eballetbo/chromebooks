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
        # random number in range 1 to 10
        seconds=$(shuf -i 1-10 -n 1)
        rtcwake -d rtc0 -m mem -s ${seconds}
        # wait at least for 5 seconds for errors to appear
        sleep 5
        # and look for errors in dmesg
        dmesg -c -l err | grep ' '
        if [ $? -eq 0 ]; then
                test_report_exit fail
	else
		test_report pass
	fi
done

exit 0
