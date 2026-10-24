#!/bin/bash
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
    echo "Run this installer with sudo: sudo ./install.sh" >&2
    exit 1
fi

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# Check the booted controller, rather than grepping config.txt: overlays may
# be in conditional sections or include files that do not apply to this Pi.
if [ ! -e /sys/class/udc/fe980000.usb ]; then
    echo "ERROR: the Pi 4 USB device controller fe980000.usb is not available." >&2
    echo "In /boot/firmware/config.txt, under [all], set:" >&2
    echo "  dtoverlay=dwc2,dr_mode=peripheral" >&2
    echo "Remove any conflicting dwc2 dr_mode=host setting that applies to this Pi." >&2
    echo "Reboot after editing, then run the installer again. See README.md." >&2
    exit 1
fi

apt-get update
apt-get install -y alsa-utils

install -m 0755 scripts/ps5-audio-gadget.sh /usr/local/sbin/ps5-audio-gadget.sh
install -m 0755 scripts/ps5-audio-bridge.sh /usr/local/sbin/ps5-audio-bridge.sh
install -m 0755 scripts/ps5-mic-bridge.sh /usr/local/sbin/ps5-mic-bridge.sh
install -m 0644 systemd/*.service /etc/systemd/system/

systemctl daemon-reload
systemctl enable ps5-audio-gadget.service ps5-audio-bridge.service ps5-mic-bridge.service

echo
echo "Installed and enabled. Reboot the Pi with the RODECaster connected to a USB-A host port."
echo "After reboot, check: systemctl status ps5-audio-gadget ps5-audio-bridge ps5-mic-bridge"
