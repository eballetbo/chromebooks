#!/bin/sh

USER=${1-debian}

adduser --gecos "$USER" \
	--disabled-password \
	--shell /bin/bash \
	"$USER"
# Add to the audio group to fix “Dummy Output” on audio
adduser "$USER" audio
adduser "$USER" sudo
echo "$USER:$USER" | chpasswd
