#!/bin/bash
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
    echo "Run with sudo: sudo ./uninstall.sh" >&2
    exit 1
fi

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# Missing units are harmless on a repeated or partial uninstall, but do not
# delete files or tear down the gadget while a service is still running.
systemctl disable --now ps5-mic-bridge.service ps5-audio-bridge.service ps5-audio-gadget.service || true
if systemctl is-active --quiet ps5-mic-bridge.service ps5-audio-bridge.service ps5-audio-gadget.service; then
    echo "A bridge service is still active. Check systemctl status before retrying." >&2
    exit 1
fi

# Also handles older installations whose gadget service had no ExecStop.
bash scripts/ps5-audio-gadget.sh stop

rm -f /etc/systemd/system/ps5-mic-bridge.service \
      /etc/systemd/system/ps5-audio-bridge.service \
      /etc/systemd/system/ps5-audio-gadget.service \
      /usr/local/sbin/ps5-mic-bridge.sh \
      /usr/local/sbin/ps5-audio-bridge.sh \
      /usr/local/sbin/ps5-audio-gadget.sh
systemctl daemon-reload

echo "USB gadget disconnected; services and scripts removed."
echo "The installer never edits /boot/firmware/config.txt, so remove the peripheral dtoverlay manually if desired."
