FROM debian:buster-slim

ARG DEBIAN_FRONTEND=noninteractive

# Docker for jenkins really needs procps otherwise the jenkins side fails
RUN apt-get update && apt-get install  --no-install-recommends -y procps

# Set HOME to a writable directory in case something wants to cache things
# (e.g. obs)
ENV HOME=/tmp

# Basic tools
RUN apt-get update  && \
    apt-get install  --no-install-recommends -y devscripts osc quilt fakeroot

# Kernel builds-depends
RUN apt-get update  && \
    apt-get install  --no-install-recommends -y build-essential \
                                                debhelper \
                                                dh-exec \
                                                cpio \
                                                kernel-wedge \
                                                kmod \
                                                bc \
                                                libssl-dev:native  \
                                                asciidoc-base  \
                                                xmlto  \
                                                bison  \
                                                flex \
                                                libaudit-dev  \
                                                libbabeltrace-dev \
                                                libbabeltrace-ctf-dev  \
                                                libdw-dev  \
                                                libelf-dev \
                                                libiberty-dev  \
                                                libnewt-dev  \
                                                libnuma-dev  \
                                                libperl-dev  \
                                                libunwind8-dev  \
                                                python-dev \
                                                autoconf  \
                                                automake  \
                                                libtool  \
                                                libglib2.0-dev  \
                                                libudev-dev  \
                                                libwrap0-dev  \
                                                rsync \
                                                libpci-dev  \
                                                libssl-dev  \
                                                bsdmainutils  \
                                                gcc  \
                                                gcc-arm-linux-gnueabihf  \
                                                gcc-aarch64-linux-gnu

