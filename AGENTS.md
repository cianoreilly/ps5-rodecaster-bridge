# AGENTS.md

## What this repo is

This project makes a Raspberry Pi 4 act as a USB audio bridge between a PlayStation 5 / PS5 Pro and a RØDECaster Duo.

The PS5 sees the Pi as a simple UAC1 USB audio device. The Pi then passes audio between that gadget device and the RØDECaster using ALSA `alsaloop`, with sample-rate correction to deal with clock drift.

There are two independent paths:

- PS5 audio -> UAC1 gadget capture -> Pi -> RØDECaster Duo playback
- RØDECaster Duo capture -> Pi -> UAC1 gadget playback -> PS5 microphone

The original direction for this solution came from u/pnkx's Reddit post linked in the README. Keep that attribution intact.

## What has actually been tested

The known-good setup is:

- PS5 Pro
- Raspberry Pi 4 Model B, 1 GB, revision `a03115`
- Raspberry Pi OS Lite 64-bit / Debian 13 (trixie)
- RØDECaster Duo connected to the Pi over USB 2 / Secondary
- Pi USB-C connected to the PS5 Pro front USB-C port for both power and USB gadget data
- 48 kHz, stereo, 16-bit UAC1 gadget
- `alsaloop --sync=samplerate`
- 30 ms latency in both directions
- RØDECaster USB 2 mix-minus enabled for the microphone path

On this hardware, 20 ms and 25 ms produced playback underruns. 30 ms was stable, as was 50 ms. Do not change the default below 30 ms just because a lower value looks nicer.

A standard PS5 and the RØDECaster Pro II have not been personally tested by the repo author. Avoid changing README wording to imply that they have been verified unless there is actual test evidence.

## Important implementation details

The Pi 4 USB-C controller must run in peripheral/device mode. A `dtoverlay=dwc2,dr_mode=host` entry conflicts with this setup.

The ConfigFS gadget is UAC1 rather than UAC2 because the goal is a simple USB audio device the PS5 will enumerate reliably.

The gadget exposes playback and capture at 48 kHz, stereo, 16-bit.

The RØDECaster Duo's playback side is natively 24-bit (`S24_3LE`). The playback bridge deliberately uses `plughw:Duo` so ALSA handles conversion from the gadget's 16-bit stream. Do not casually replace this with `hw:Duo`.

Use the ALSA card name `Duo` rather than a numeric card index. Card numbers changed between boots during testing.

The two audio directions are separate systemd services on purpose. This makes them easier to diagnose and allows one direction to restart without taking down the other.

The services normally run as root, which also allows `alsaloop` to obtain real-time scheduling. During manual non-root testing it could not set Round Robin priority 99; under root it could.

For microphone support, USB 2 mix-minus on the RØDECaster is important. Without it, PS5 playback can be sent back to the PS5 as microphone audio and create an echo/feedback path.

## Repo layout

- `scripts/ps5-audio-gadget.sh` - creates and binds the ConfigFS UAC1 gadget
- `scripts/ps5-audio-bridge.sh` - PS5 -> RØDECaster audio
- `scripts/ps5-mic-bridge.sh` - RØDECaster -> PS5 microphone
- `systemd/` - services for the three components above
- `install.sh` - installs scripts/services and enables them
- `uninstall.sh` - removes the installed services/scripts
- `docs/TROUBLESHOOTING.md` - diagnostic notes
- `README.md` - user-facing setup and background

## Working on the repo

Prefer small, understandable shell scripts over adding dependencies or building a larger daemon. This project should remain something a Raspberry Pi user can inspect and debug with standard Linux tools.

Shell changes should be compatible with Bash on Raspberry Pi OS. Quote variables, fail clearly, and avoid depending on ALSA numeric card ordering.

Do not silently rewrite `/boot/firmware/config.txt` in a destructive way. If installer behavior around `dwc2` is changed, preserve unrelated user configuration and make the required modification obvious.

Keep latency configurable if adding configuration support, but retain 30 ms as the documented default until testing shows a better broadly safe value.

Do not remove the u/pnkx acknowledgement or present the core technique as originating in this repository.

Keep the README fairly informal and practical. It is intentionally written as notes from someone who built and tested the setup, not as polished product documentation.

## Validation after changes

There is no meaningful CI substitute for the USB/audio hardware path. At minimum, statically inspect shell changes and run `bash -n` on every `.sh` file.

On real hardware, the useful checks are:

```bash
cat /sys/kernel/config/usb_gadget/ps5audio/UDC
cat /sys/class/udc/fe980000.usb/state
cat /sys/class/udc/fe980000.usb/current_speed
cat /proc/asound/cards
vcgencmd get_throttled
systemctl status ps5-audio-gadget.service ps5-audio-bridge.service ps5-mic-bridge.service
```

A healthy PS5-connected gadget should normally show `configured` and `high-speed`, with both `UAC1Gadget` and `Duo` present in `/proc/asound/cards`.

For an end-to-end test, verify all of the following:

1. The PS5 lists `PS5 Audio Bridge` as an audio device.
2. PS5 audio reaches headphones/monitoring through the RØDECaster.
3. The RØDECaster microphone reaches the PS5 microphone-level screen.
4. Playing PS5 audio while staying silent does not substantially move the PS5 microphone meter (mix-minus check).
5. Sustained audio does not produce `alsaloop` underruns or audible crackling/drift.
6. Everything returns automatically after a cold boot of the Pi/PS5.

If hardware testing was not performed for a change, say so rather than describing it as tested.
