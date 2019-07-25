#!/bin/sh

USER=${1-debian}

adduser --gecos "$USER" \
	--disabled-password \
	--shell /bin/bash \
	"$USER"
# Add to the audio group to fix “Dummy Output” on audio
adduser "$USER" audio
adduser "$USER" render
adduser "$USER" sudo
adduser "$USER" video
echo "$USER:$USER" | chpasswd
