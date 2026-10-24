# Troubleshooting

These are the checks that were useful while I was getting the bridge working.

## PS5 doesn't see `PS5 Audio Bridge`

First check that the Pi has a USB device controller:

```bash
ls /sys/class/udc/
```

On my Pi 4 this is `fe980000.usb`.

Then check the gadget:

```bash
cat /sys/kernel/config/usb_gadget/ps5audio/UDC
cat /sys/class/udc/fe980000.usb/state
cat /sys/class/udc/fe980000.usb/current_speed
```

With the Pi connected to the PS5 I get `configured` and `high-speed`.

If `/sys/class/udc/` is empty, double-check `dtoverlay=dwc2,dr_mode=peripheral` in `/boot/firmware/config.txt` and make sure you don't also have `dwc2,dr_mode=host` enabled.

Put the peripheral setting under `[all]` and reboot after changing it. The installer checks the running controller, so editing the file alone is not enough.

If gadget setup failed but the controller is now available, retry all three services:

```bash
sudo systemctl restart ps5-audio-gadget ps5-audio-bridge ps5-mic-bridge
```

The gadget script rebuilds any unbound configuration left behind by a failed start. Restarting only the gadget service can leave the dependent bridges stopped, so include both bridges in the command.

## Check the audio devices

```bash
cat /proc/asound/cards
aplay -l
arecord -l
```

The scripts expect the ALSA names `Duo` and `UAC1Gadget`.

## Check the services

```bash
systemctl status ps5-audio-gadget
systemctl status ps5-audio-bridge
systemctl status ps5-mic-bridge
```

For logs from the current boot:

```bash
journalctl -u ps5-audio-gadget -b
journalctl -u ps5-audio-bridge -b
journalctl -u ps5-mic-bridge -b
```

## Crackling / underruns

30 ms was stable on my Pi. 20 ms and 25 ms weren't.

If you still get underruns, use the [latency override instructions in the README](../README.md#latency) to set `LATENCY_US=50000` (50 ms) for both installed services, then:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ps5-audio-bridge ps5-mic-bridge
```

## Check power

```bash
vcgencmd get_throttled
```

Mine reports:

```text
throttled=0x0
```

The front USB-C port on my PS5 Pro has been enough to power the Pi 4 in this setup.

## Mic works, but PS5 audio is going back into voice chat

Set the RØDECaster's **USB 2** routing to **Mix-minus**. The Pi is connected to USB 2, so you don't want USB 2's return audio included in the mix being sent back to the PS5.

## USB-C weirdness on an early Pi 4

Revision 1.1 Pi 4 boards have a known USB-C CC resistor issue with some e-marked cables. If the gadget never enumerates, try a basic USB 2 data-capable cable.
