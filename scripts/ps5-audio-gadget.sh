#!/bin/bash
set -euo pipefail

G=/sys/kernel/config/usb_gadget/ps5audio
UDC=fe980000.usb

# ConfigFS attributes are kernel-owned files. Remove only our symlink and
# directories, in dependency order; never recursively delete a ConfigFS tree.
remove_gadget() {
    local bound_udc dir
    [ -d "$G" ] || return 0

    bound_udc=$(cat "$G/UDC")
    if [ -n "$bound_udc" ]; then
        echo "" > "$G/UDC"
    fi
    rm -f "$G/configs/c.1/uac1.usb0"
    for dir in configs/c.1/strings/0x409 configs/c.1 functions/uac1.usb0 strings/0x409; do
        if [ -d "$G/$dir" ]; then
            rmdir "$G/$dir"
        fi
    done
    rmdir "$G"
}

case "${1:-start}" in
    start) ;;
    stop)
        remove_gadget
        exit 0
        ;;
    *)
        echo "Usage: $0 [start|stop]" >&2
        exit 1
        ;;
esac

modprobe libcomposite
modprobe usb_f_uac1

if ! mountpoint -q /sys/kernel/config; then
    mount -t configfs none /sys/kernel/config
fi

# A bound gadget has completed setup. An unbound one may be left over from
# a failed start, so remove it before rebuilding its configuration.
if [ -d "$G" ]; then
    bound_udc=$(cat "$G/UDC")
    if [ "$bound_udc" = "$UDC" ]; then
        exit 0
    elif [ -n "$bound_udc" ]; then
        echo "Gadget is already bound to unexpected controller $bound_udc" >&2
        exit 1
    fi
    remove_gadget
fi

for _ in {1..20}; do
    [ -e "/sys/class/udc/$UDC" ] && break
    sleep 0.5
done

if [ ! -e "/sys/class/udc/$UDC" ]; then
    echo "USB device controller $UDC did not appear; check peripheral mode and reboot" >&2
    exit 1
fi

mkdir "$G"
cd "$G"

echo 0x1d6b > idVendor
echo 0x0104 > idProduct
echo 0x0200 > bcdUSB
echo 0x0100 > bcdDevice

mkdir -p strings/0x409
echo "PS5AUDIO001" > strings/0x409/serialnumber
echo "PS5 RODECaster Bridge" > strings/0x409/manufacturer
echo "PS5 Audio Bridge" > strings/0x409/product

mkdir -p configs/c.1/strings/0x409
echo "PS5 Audio" > configs/c.1/strings/0x409/configuration
echo 100 > configs/c.1/MaxPower

mkdir functions/uac1.usb0
echo 3 > functions/uac1.usb0/p_chmask
echo 48000 > functions/uac1.usb0/p_srate
echo 2 > functions/uac1.usb0/p_ssize
echo 3 > functions/uac1.usb0/c_chmask
echo 48000 > functions/uac1.usb0/c_srate
echo 2 > functions/uac1.usb0/c_ssize

ln -s functions/uac1.usb0 configs/c.1/

echo "$UDC" > UDC
