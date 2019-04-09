#!/usr/bin/env bash

# Exit on error. Append "|| true" if you expect an error.
set -e
# Turn on traces, useful while debugging but commented out by default
#set -x

# Current Working Directory
CWD=$(dirname $(readlink -f $0))

print_usage_exit()
{
    local arg_ret="${1-1}"

    echo "
ARM/ARM64 kernel build tool.

Usage:

  $0 OPTIONS COMMAND

Options:

  The following options are common to all commands. Only --architecture
  is compulsory.

  --architecture=ARCH Kernel architecture, ARCH needs to be one of the
                      following: arm | arm64

Available commands:

  help
    Print this help message.

  do_everything
    Do everything in one command with default settings.

  do_configure
    Configure the Linux kernel.

  do_compile
    Compile the Linux kernel.

For example, to do everything for an ARM kernel:

  $0 --architecture=arm do_everything
"

    exit $arg_ret
}

# -----------------------------------------------------------------------------
# Utility functions

jopt()
{
    echo "-j"$(grep -c processor /proc/cpuinfo)
}

# -----------------------------------------------------------------------------
# Command functions

cmd_do_configure()
{
    local defconfig

    # Create .config
    if [ "$ARCH" == "arm" ]; then
        make multi_v7_defconfig
    else
        make defconfig
    fi

    make olddefconfig
}

cmd_do_compile()
{
    make $(jopt)
}

cmd_do_everything()
{
    cmd_do_configure
    cmd_do_compile
    echo "All done."
}

# -----------------------------------------------------------------------------
# Parse program options

opts=$(getopt -o "s:" -l "architecture:" -- "$@")
eval set -- "$opts"

while true; do
    case "$1" in
        --architecture)
            ARCH="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Internal error"
            exit 1
            ;;
    esac
done

cmd="$1"
[ -z "$cmd" ] && print_usage_exit
shift

# -----------------------------------------------------------------------------
# Options sanitising

[ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || {
    echo "Invalid architecture argument passed to the --architecture option."
    print_usage_exit
}

if [ "$ARCH" == "arm" ]; then
    [ -z "$CROSS_COMPILE" ] && export CROSS_COMPILE=arm-linux-gnueabihf-
else
    [ -z "$CROSS_COMPILE" ] && export CROSS_COMPILE=aarch64-linux-gnu-
fi

export ARCH

# Run the command if it's valid, otherwise abort
type cmd_$cmd > /dev/null 2>&1 || print_usage_exit
cmd_$cmd $@

exit 0
