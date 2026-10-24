#!/bin/bash
set -euo pipefail

LATENCY_US="${LATENCY_US:-30000}"

for _ in {1..60}; do
    if grep -q "UAC1Gadget" /proc/asound/cards && grep -q "Duo" /proc/asound/cards; then
        exec /usr/bin/alsaloop \
            -C hw:Duo \
            -P hw:UAC1Gadget \
            -r 48000 -c 2 \
            --sync=samplerate \
            -t "$LATENCY_US"
    fi
    sleep 1
done

echo "UAC1Gadget or RODECaster Duo did not become available" >&2
exit 1
