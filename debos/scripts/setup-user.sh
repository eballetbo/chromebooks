#!/bin/sh

USER=${1-debian}

adduser --gecos "$USER" \
	  --disabled-password \
	    --shell /bin/bash \
	      "$USER"
adduser "$USER" sudo
echo "$USER:$USER" | chpasswd
