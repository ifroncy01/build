#!/bin/bash

rfkill unblock all
if hciconfig hci0 up 2>/dev/null; then
	echo "Bluetooth hci0 already initialized by kernel driver"
	exit 0
fi
sleep 1
exec hciattach -n -s 115200 /dev/ttyS9 bcm43xx 1500000