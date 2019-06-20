#!/bin/sh

USER=${1-debian}

adduser --gecos "$USER" \
        --disabled-password \
        --shell /bin/bash \
        "$USER"

adduser "$USER" sudo
adduser "$USER" video
adduser "$USER" render

echo "$USER:$USER" | chpasswd
