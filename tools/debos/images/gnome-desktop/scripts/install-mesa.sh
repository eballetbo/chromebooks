#!/bin/sh

set -e

apt-get install -y libllvm8

dpkg -i /root/packages/*.deb

