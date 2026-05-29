#!/bin/bash
set -e

echo "[BT] Initializing AP6255 Bluetooth (vendor kernel)"

if hciconfig hci0 up 2>/dev/null; then
	echo "[BT] hci0 already initialized by kernel serdev"
	exit 0
fi

rfkill unblock all
sleep 1

if [ -d /sys/class/rfkill/rfkill0 ]; then
	echo 1 > /sys/class/rfkill/rfkill0/state 2>/dev/null || echo "[BT] rfkill0 state write failed (non-fatal)"
fi
sleep 1

echo "[BT] Attaching hciattach on /dev/ttyS8"
exec hciattach -n -s 115200 /dev/ttyS8 bcm43xx 1500000