#!/usr/bin/env python
# -*- coding: utf-8 -*-

from ctypes import *
import errno
import fcntl
import os
import sys
import unittest

EC_CMD_PROTO_VERSION    = 0x0000
EC_CMD_HELLO            = 0x0001
EC_CMD_GET_VERSION      = 0x0002
EC_CMD_GET_FEATURES     = 0x000D

EC_HOST_PARAM_SIZE      = 0xfc

EC_DEV_IOCXCMD          = 0xc014ec00  # _IOWR(EC_DEV_IOC, 0, struct cros_ec_command)

ECFEATURES              = -1
# Supported features
EC_FEATURE_LIMITED                          = 0
EC_FEATURE_FLASH                            = 1
EC_FEATURE_PWM_FAN                          = 2
EC_FEATURE_PWM_KEYB                         = 3
EC_FEATURE_LIGHTBAR                         = 4
EC_FEATURE_LED                              = 5
EC_FEATURE_MOTION_SENSE                     = 6
EC_FEATURE_KEYB                             = 7
EC_FEATURE_PSTORE                           = 8
EC_FEATURE_PORT80                           = 9
EC_FEATURE_THERMAL                          = 10
EC_FEATURE_BKLIGHT_SWITCH                   = 11
EC_FEATURE_WIFI_SWITCH                      = 12
EC_FEATURE_HOST_EVENTS                      = 13
EC_FEATURE_GPIO                             = 14
EC_FEATURE_I2C                              = 15
EC_FEATURE_CHARGER                          = 16
EC_FEATURE_BATTERY                          = 17
EC_FEATURE_SMART_BATTERY                    = 18
EC_FEATURE_HANG_DETECT                      = 19
EC_FEATURE_PMU                              = 20
EC_FEATURE_SUB_MCU                          = 21
EC_FEATURE_USB_PD                           = 22
EC_FEATURE_USB_MUX                          = 23
EC_FEATURE_MOTION_SENSE_FIFO                = 24
EC_FEATURE_VSTORE                           = 25
EC_FEATURE_USBC_SS_MUX_VIRTUAL              = 26
EC_FEATURE_RTC                              = 27
EC_FEATURE_FINGERPRINT                      = 28
EC_FEATURE_TOUCHPAD                         = 29
EC_FEATURE_RWSIG                            = 30
EC_FEATURE_DEVICE_EVENT                     = 31
EC_FEATURE_UNIFIED_WAKE_MASKS               = 32
EC_FEATURE_HOST_EVENT64                     = 33
EC_FEATURE_EXEC_IN_RAM                      = 34
EC_FEATURE_CEC                              = 35
EC_FEATURE_MOTION_SENSE_TIGHT_TIMESTAMPS    = 36
EC_FEATURE_REFINED_TABLET_MODE_HYSTERESIS   = 37
EC_FEATURE_SCP                              = 39
EC_FEATURE_ISH                              = 40

class cros_ec_command(Structure):
    _fields_ = [
        ('version', c_uint),
        ('command', c_uint),
        ('outsize', c_uint),
        ('insize', c_uint),
        ('result', c_uint),
        ('data', c_ubyte * EC_HOST_PARAM_SIZE)
    ]

class ec_params_hello(Structure):
    _fields_ = [
        ('in_data', c_uint)
    ]

class ec_response_hello(Structure):
    _fields_ = [
        ('out_data', c_uint)
    ]

class ec_params_get_features(Structure):
    _fields_ = [
        ('in_data', c_ulong)
    ]

class ec_response_get_features(Structure):
    _fields_ = [
        ('out_data', c_ulong)
    ]

def EC_FEATURE_MASK_0(event_code):
    return (1 << (event_code % 32))

def EC_FEATURE_MASK_1(event_code):
    return (1 << (event_code - 32))

def is_feature_supported(feature):
    global ECFEATURES

    if ECFEATURES == -1:
        fd = open("/dev/cros_ec", 'r')

        param = ec_params_get_features()
        response = ec_response_get_features()

        cmd = cros_ec_command()
        cmd.version = 0
        cmd.command = EC_CMD_GET_FEATURES
        cmd.insize = sizeof(param)
        cmd.outsize = sizeof(response)

        memmove(addressof(cmd.data), addressof(param), cmd.outsize)
        fcntl.ioctl(fd, EC_DEV_IOCXCMD, cmd)
        memmove(addressof(response), addressof(cmd.data), cmd.outsize)

        fd.close()

        if cmd.result == 0:
            ECFEATURES = response.out_data
        else:
            return False

    return (ECFEATURES & EC_FEATURE_MASK_0(feature)) > 0

###############################################################################
# TEST RUNNERS
###############################################################################

class LavaTextTestResult(unittest.TestResult):

    def __init__(self, runner):
        unittest.TestResult.__init__(self)
        self.runner = runner

    def addSuccess(self, test):
        unittest.TestResult.addSuccess(self, test)
        self.runner.writeUpdate("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=%s RESULT=pass>\n" % test.id())

    def addError(self, test, err):
        unittest.TestResult.addError(self, test, err)
        self.runner.writeUpdate("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=%s RESULT=unknown>\n" % test.id())

    def addFailure(self, test, err):
        unittest.TestResult.addFailure(self, test, err)
        self.runner.writeUpdate("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=%s RESULT=fail>\n" % test.id())

    def addSkip(self, test, reason):
        unittest.TestResult.addSkip(self, test, reason)
        self.runner.writeUpdate("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=%s RESULT=skip>\n" % test.id())

class LavaTestRunner:

    def __init__(self, stream=sys.stderr, verbosity=0):
        self.stream = stream
        self.verbosity = verbosity

    def writeUpdate(self, message):
        self.stream.write(message)

    def run(self, test):
        result = LavaTextTestResult(self)
        test(result)
        result.testsRun
        return result

###############################################################################
# TEST SUITES
###############################################################################

class TestCrosEC(unittest.TestCase):

    def test_cros_ec_chardev(self):
        self.assertEqual(os.path.exists("/dev/cros_ec"), 1)

    # Hello.  This is a simple command to test the EC is responsive to commands
    def test_cros_ec_hello(self):
        fd = open("/dev/cros_ec", 'r')
        param = ec_params_hello()
        param.in_data = 0xa0b0c0d0 # magic number that the EC expects on HELLO

        response = ec_response_hello()

        cmd = cros_ec_command()
        cmd.version = 0
        cmd.command = EC_CMD_HELLO
        cmd.insize = sizeof(param)
        cmd.outsize = sizeof(response)

        memmove(addressof(cmd.data), addressof(param), cmd.outsize)
        fcntl.ioctl(fd, EC_DEV_IOCXCMD, cmd)
        memmove(addressof(response), addressof(cmd.data), cmd.insize)

        fd.close()

        self.assertEqual(cmd.result, 0)
        # magic number that the EC answers on HELLO
        self.assertEqual(response.out_data, 0xa1b2c3d4)

    # EC_FEATURE_BATTERY: Battery cutoff at-shutdown
    def test_cros_ec_battery_cutoff_at_shutdown(self):
        if not is_feature_supported(EC_FEATURE_BATTERY):
            self.skipTest("EC_FEATURE_BATTERY not supported, skipping")

        self.assertEqual(os.path.exists("/sys/class/chromeos/cros_ec/" + "battery_cutoff"), 1)

        fd = open("/sys/class/chromeos/cros_ec/" + "battery_cutoff", 'w')
        fd.write("at-shutdown")
        fd.close()

        fd = open("/sys/class/chromeos/cros_ec/" + "battery_cutoff", 'w')
        fd.write("at-shutdown\n")
        fd.close()

        with self.assertRaises(IOError) as cm:
            fd = open("/sys/class/chromeos/cros_ec/" + "battery_cutoff", 'w')
            fd.write("at-shutdown-")
            fd.close()
            self.assertEqual(cm.exception.error_code, 22)

        with self.assertRaises(IOError) as cm:
            fd = open("/sys/class/chromeos/cros_ec/" + "battery_cutoff", 'w')
            fd.write("at-shutdow-")
            fd.close()
            self.assertEqual(cm.exception.error_code, 22)

        with self.assertRaises(IOError) as cm:
            fd = open("/sys/class/chromeos/cros_ec/" + "battery_cutoff", 'w')
            fd.write("at-shutdow")
            fd.close()
            self.assertEqual(cm.exception.error_code, 22)

    def test_cros_ec_accel_iio_abi(self):
        match = 0
        for devname in os.listdir("/sys/bus/iio/devices"):
            fd = open("/sys/bus/iio/devices/" + devname + "/name", 'r')
            devtype = fd.read()
            if devtype.startswith("cros-ec-accel"):
                files = [ "buffer", "calibrate", "current_timestamp_clock",
                          "frequency", "id", "in_accel_x_calibbias",
                          "in_accel_x_calibscale", "in_accel_x_raw",
                          "in_accel_y_calibbias", "in_accel_y_calibscale",
                          "in_accel_y_raw", "in_accel_z_calibbias",
                          "in_accel_z_calibscale", "in_accel_z_raw",
                          "location", "sampling_frequency",
                          "sampling_frequency_available", "scale",
                          "scan_elements/", "trigger/"]
                match += 1
                for filename in files:
                    self.assertEqual(os.path.exists("/sys/bus/iio/devices/" + devname + "/" + filename), 1)
            fd.close()
        if match == 0:
            self.skipTest("No accelerometer found, skipping")

if __name__ == '__main__':
    unittest.main(testRunner=LavaTestRunner(),
        # these make sure that some options that are not applicable
        # remain hidden from the help menu.
        failfast=False, buffer=False, catchbreak=False)

