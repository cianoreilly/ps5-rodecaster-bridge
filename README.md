# PS5 RØDECaster USB bridge

I put this together after running into problems using a RØDECaster Duo directly with a PS5 Pro.

The Duo would work over USB, but the audio would eventually start crackling / sounding robotic. The workaround is to put a Raspberry Pi 4 in between them. The Pi shows up to the PS5 as a basic USB audio device and uses `alsaloop` to bridge audio to and from the RØDECaster while correcting for clock drift.

I've been using this with a PS5 Pro and RØDECaster Duo. Both game audio and the microphone work, and it survives a cold boot without needing to SSH into the Pi.

## Credit

This is based on the approach described by **u/pnkx** in this post on r/rode:

[Fixed the RØDECaster Duo / Pro II → PS5 USB audio problem with a Raspberry Pi 4](https://www.reddit.com/r/rode/comments/1wjj9de/fixed_the_r%C3%B8decaster_duo_pro_ii_ps5_usb_audio/)

That post is what sent me down the right path, particularly using the Pi as a UAC1 gadget and `alsaloop --sync=samplerate` to deal with the clock difference. It also describes systemd services and a reverse audio loop for microphone support.

This repo packages my implementation of that approach, with separate services for each audio direction, install/uninstall scripts, troubleshooting notes, and the latency values I tested on my Pi.

## Setup

```text
PS5 Pro USB-C
      |
      | USB-C (Pi gadget port)
      v
Raspberry Pi 4
      |
      | USB-A -> USB-C
      v
RØDECaster Duo USB 2

PC -> RØDECaster Duo USB 1 (unchanged)
```

The Pi handles both directions:

```text
PS5 audio  -> Pi -> RØDECaster -> headphones
PS5 mic    <- Pi <- RØDECaster <- microphone
```

## Hardware I tested this with

- PS5 Pro
- Raspberry Pi 4 Model B 1 GB, revision `a03115`
- Raspberry Pi OS Lite 64-bit (Debian 13 / Trixie)
- RØDECaster Duo
- Shure SM7B

The Pi is powered directly from the front USB-C port on my PS5 Pro. `vcgencmd get_throttled` reports `0x0` on my setup.

I haven't personally tested a standard PS5 or RØDECaster Pro II yet. They may work, but I don't want to claim they do until somebody tries them.

## Install

Start with Raspberry Pi OS Lite and install `alsa-utils`:

```bash
sudo apt update
sudo apt full-upgrade -y
sudo apt install -y alsa-utils
```

Edit `/boot/firmware/config.txt` and make sure the USB controller is set to peripheral mode. Put this under an `[all]` section so it applies to the Pi 4:

```ini
[all]
dtoverlay=dwc2,dr_mode=peripheral
```

If you have an active `dr_mode=host` line for `dwc2`, remove it or comment it out.

Reboot and check that the USB device controller exists:

```bash
ls /sys/class/udc/
```

Mine shows:

```text
fe980000.usb
```

Then clone/copy this repo to the Pi and run:

```bash
cd ps5-rodecaster-bridge
sudo ./install.sh
sudo reboot
```

I deliberately don't have the installer modify `config.txt` for you. It checks that `fe980000.usb` is available in the running system, so reboot after changing the USB controller settings before installing.

## RØDECaster routing

Connect the Pi to **USB 2 / Secondary** on the RØDECaster. Your PC can stay connected to USB 1 Main/Chat as normal.

If you want the microphone to work, set the RØDECaster's USB 2 output to **Mix-minus**. Otherwise the PS5 audio coming into USB 2 can get sent straight back to the PS5 as part of the mic mix.

## PS5 settings

After rebooting, the PS5 should see:

```text
PS5 Audio Bridge
```

Select that as the output device and microphone input.

You can check everything on the Pi with:

```bash
systemctl status ps5-audio-gadget
systemctl status ps5-audio-bridge
systemctl status ps5-mic-bridge
```

## Latency

I'm using **30 ms** in both directions.

I tried a few values on my Pi:

| Target | What happened |
| ---: | --- |
| 20 ms | underruns |
| 25 ms | underrun |
| 30 ms | stable |
| 50 ms | stable |

So 30 ms isn't a special requirement; it was just the lowest value that was reliable on my setup. If you're getting underruns, try 50 ms.

The default is `LATENCY_US=30000` (microseconds). To try 50 ms, create an override for each installed bridge service:

```bash
sudo systemctl edit ps5-audio-bridge.service
sudo systemctl edit ps5-mic-bridge.service
```

In each editor, add this above the comment marking the end of the editable area, then save:

```ini
[Service]
Environment=LATENCY_US=50000
```

Apply it with:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ps5-audio-bridge ps5-mic-bridge
```

Use `30000` in both overrides to return to the default. These overrides survive reinstalling the scripts and services; editing files in the downloaded repo alone won't change the running setup.

## What's actually happening?

The PS5 talks to a USB Audio Class 1 gadget created on the Pi. On the other side, the Pi sees the RØDECaster as a normal USB audio interface.

The important bit is `alsaloop --sync=samplerate`. The PS5 side and the RØDECaster each have their own audio clock, and those clocks aren't perfectly identical. `alsaloop` makes tiny sample-rate adjustments so one side doesn't slowly run ahead of the other and empty/overflow the audio buffers.

The two loops are essentially:

```bash
# PS5 -> RØDECaster
alsaloop -C hw:UAC1Gadget -P plughw:Duo -r 48000 -c 2 --sync=samplerate -t 30000

# RØDECaster -> PS5 (mic)
alsaloop -C hw:Duo -P hw:UAC1Gadget -r 48000 -c 2 --sync=samplerate -t 30000
```

The systemd services just start those automatically once both USB audio devices are available.

## Problems

There's a short troubleshooting guide in [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

A few things worth checking first:

```bash
cat /proc/asound/cards
vcgencmd get_throttled
cat /sys/class/udc/fe980000.usb/state
```

You should see both `Duo` and `UAC1Gadget` in `/proc/asound/cards`, no power throttling, and the UDC state should be `configured` while connected to the PS5.

One other thing: early revision 1.1 Raspberry Pi 4 boards have the known USB-C CC resistor issue. If you have one of those and the Pi refuses to enumerate, try a simple non-e-marked USB 2 data cable.

## Uninstall

```bash
sudo ./uninstall.sh
```

This stops the bridges, disconnects the USB gadget from the PS5, and removes the scripts and services. It doesn't touch `/boot/firmware/config.txt`. Any service overrides you created with `systemctl edit` are kept and will apply if you reinstall.

## License

MIT. See [`LICENSE`](LICENSE).
