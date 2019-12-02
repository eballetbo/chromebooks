#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from ctypes import *
import errno
import fcntl
import math
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

def read_file(name):
    fd = open(name, 'r')
    contents = fd.read()
    fd.close()
    return contents

# Return an int froom kernel version to allow to compare
def version_to_int(version, major, minor):
    pattern = "{0:03d}{1:03d}{2:03d}"
    return int(pattern.format(version, major, minor))

# Return the running kernel version
def current_kernel_version():
    fd = open("/proc/version", 'r')
    current = fd.read().split()[2].split('-')[0].split('.')
    fd.close()
    return version_to_int(int(current[0]), int(current[1]), int(current[2]))

def kernel_lower_than(version, major, minor):
    if version_to_int(version, major, minor) > current_kernel_version():
        return True
    return False

def kernel_greater_than(version, major, minor):
    if version_to_int(version, major, minor) < current_kernel_version():
        return True
    return False

def sysfs_check_attributes_exists(s, path, name, files, check_devtype):
    match = 0
    for devname in os.listdir(path):
        if check_devtype:
            fd = open(path + "/" + devname + "/name", 'r')
            devtype = fd.read()
            fd.close()
            if not devtype.startswith(name):
                continue
        else:
            if not devname.startswith(name):
                continue
        match += 1
        for filename in files:
            s.assertEqual(os.path.exists(path + "/" + devname + "/" + filename), 1)
    if match == 0:
        s.skipTest("No " + name + " found, skipping")

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

    def test_cros_ec_accel_iio_abi(self):
        files = [ "buffer", "calibrate", "current_timestamp_clock", "id",
                  "in_accel_x_calibbias", "in_accel_x_calibscale",
                  "in_accel_x_raw", "in_accel_y_calibbias",
                  "in_accel_y_calibscale", "in_accel_y_raw",
                  "in_accel_z_calibbias", "in_accel_z_calibscale",
                  "in_accel_z_raw", "location", "sampling_frequency",
                  "sampling_frequency_available", "scale",
                  "scan_elements/", "trigger/"]
        sysfs_check_attributes_exists( self, "/sys/bus/iio/devices", "cros-ec-accel", files, True)
        if kernel_greater_than(5,4,0):
            sysfs_check_attributes_exists( self, "/sys/bus/iio/devices", "cros-ec-accel", ["frequency"], True)


    # This function validate accelerometer data by computing the magnitude.
    # If the magnitude is not closed to 1G, that means data are invalid or
    # the machine is in movement or there is a earth quake.
    def test_cros_ec_accel_iio_data_is_valid(self):
        ACCEL_1G_IN_MS2 = 9.8185
        ACCEL_MAG_VALID_OFFSET = .25
        match = 0
        for devname in os.listdir("/sys/bus/iio/devices"):
            base_path = "/sys/bus/iio/devices/" + devname + "/"
            fd = open(base_path + "name", 'r')
            devtype = fd.read()
            if devtype.startswith("cros-ec-accel"):
                location = read_file(base_path + "location")
                accel_scale = float(read_file(base_path + "scale"))
                exp = ACCEL_1G_IN_MS2
                err = exp * ACCEL_MAG_VALID_OFFSET
                mag = 0
                for axis in ['x', 'y', 'z']:
                    axis_path = base_path + "in_accel_" + axis + "_raw"
                    value = int(read_file(axis_path))
                    value *= accel_scale
                    mag += value * value
                mag = math.sqrt(mag)
                self.assertTrue(abs(mag - exp) <= err)
                match += 1
            fd.close()
        if match == 0:
            self.skipTest("No accelerometer found, skipping")

    def test_cros_ec_gyro_iio_abi(self):
        files = [ "buffer/", "calibrate", "current_timestamp_clock", "id",
                  "in_anglvel_x_calibbias", "in_anglvel_x_calibscale",
                  "in_anglvel_x_raw", "in_anglvel_y_calibbias",
                  "in_anglvel_y_calibscale", "in_anglvel_y_raw",
                  "in_anglvel_z_calibbias", "in_anglvel_z_calibscale",
                  "in_anglvel_z_raw", "location", "sampling_frequency",
                  "sampling_frequency_available", "scale",
                  "scan_elements/", "trigger/"]
        sysfs_check_attributes_exists( self, "/sys/bus/iio/devices", "cros-ec-gyro", files, True)
        if kernel_greater_than(5,4,0):
            sysfs_check_attributes_exists( self, "/sys/bus/iio/devices", "cros-ec-gyro", ["frequency"], True)

    def test_cros_ec_usbpd_charger_abi(self):
        files = [ "current_max", "input_current_limit",
                  "input_voltage_limit", "manufacturer", "model_name",
                  "online", "power/autosuspend_delay_ms", "status",
                  "type", "usb_type", "voltage_max_design",
                  "voltage_now"]
        sysfs_check_attributes_exists( self, "/sys/class/power_supply/", "CROS_USBPD_CHARGER", files, False)

    def test_cros_ec_battery_abi(self):
        files = [ "alarm", "capacity_level", "charge_full_design",
                  "current_now", "manufacturer", "serial_number",
                  "type", "voltage_min_design", "capacity",
                  "charge_full", "charge_now", "cycle_count",
                  "model_name", "present", "status", "technology",
                  "voltage_now"]
        sysfs_check_attributes_exists( self, "/sys/class/power_supply/", "BAT", files, False)

    def test_cros_ec_extcon_usbc_abi(self):
        match = 0
        for devname in os.listdir("/sys/class/extcon"):
            devtype = read_file("/sys/class/extcon/" + devname + "/name")
            if ".spi:ec@0:extcon@" in devtype:
                self.assertEqual(os.path.exists("/sys/class/extcon/" + devname + "/state"), 1)
                for cable in os.listdir("/sys/class/extcon/" + devname):
                    self.assertEqual(os.path.exists("/sys/class/extcon/" + devname + "/name"), 1)
                    self.assertEqual(os.path.exists("/sys/class/extcon/" + devname + "/state"), 1)
                    match += 1
        if match == 0:
            self.skipTest("No extcon device found, skipping")

    def test_cros_ec_rtc_abi(self):
        if not is_feature_supported(EC_FEATURE_RTC):
            self.skipTest("EC_FEATURE_RTC not supported, skipping")
        match = 0
        for devname in os.listdir("/sys/class/rtc"):
            fd = open("/sys/class/rtc/" + devname + "/name", 'r')
            devtype = fd.read()
            fd.close()
            if devtype.startswith("cros-ec-rtc"):
                files = [ "date", "hctosys", "max_user_freq", "since_epoch",
                          "time", "wakealarm" ]
                match += 1
                for filename in files:
                    self.assertEqual(os.path.exists("/sys/class/rtc/" + devname + "/" + filename), 1)
        self.assertNotEqual(match,0)

    def test_cros_ec_pwm_backlight(self):
        if not os.path.exists("/sys/class/backlight/backlight/max_brightness"):
            self.skipTest("No backlight pwm found, skipping")
        is_ec_pwm = False
        fd = open("/sys/kernel/debug/pwm", 'r')
        line = fd.readline()
        while line and not is_ec_pwm:
            if line[0] != ' ' and ":ec-pwm" in line:
                line = fd.readline()
                while line:
                    if line[0] == '\n':
                        is_ec_pwm = False
                        break
                    if "backlight" in line:
                        is_ec_pwm = True
                        break
                    line = fd.readline()
            line = fd.readline()
        fd.close()
        if not is_ec_pwm:
            self.skipTest("No EC backlight pwm found, skipping")
        fd = open("/sys/class/backlight/backlight/max_brightness", 'r')
        brightness = int(int(fd.read()) / 2)
        fd.close()
        fd = open("/sys/class/backlight/backlight/brightness", 'w')
        fd.write(str(brightness))
        fd.close()
        fd = open("/sys/kernel/debug/pwm", 'r')
        line = fd.readline()
        while line:
            if "backlight" in line:
                start = line.find("duty") + 6
                self.assertNotEqual(start,5)
                end = start + line[start:].find(" ")
                self.assertNotEqual(start,end)
                duty = int(line[start:end])
                self.assertNotEqual(duty,0)
                break
            line = fd.readline()
        fd.close()

if __name__ == '__main__':
    unittest.main(testRunner=LavaTestRunner(),
        # these make sure that some options that are not applicable
        # remain hidden from the help menu.
        failfast=False, buffer=False, catchbreak=False)

