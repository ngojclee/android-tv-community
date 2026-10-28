#!/bin/bash
# x96q-kvmd-otg.sh - (re)create the kvmd container with OTG HID + MSD on the X96Q.
# Community variant: no default password - WEBUSER/WEBPASS required.
set -e
IMAGE=registry.cn-hangzhou.aliyuncs.com/silentwind/kvmd:latest
WEBUSER="${WEBUSER:-admin}"
WEBPASS="${WEBPASS:-}"

if [ -z "$WEBPASS" ]; then
    echo "WEBPASS is not set - refusing to create a container with an empty password" >&2
    exit 1
fi

# 1. group + udev rule so /dev/hidg* belong to kvmd.
getent group kvmd >/dev/null || groupadd -g 1000 kvmd
echo 'KERNEL=="hidg[0-9]*", MODE="0660", GROUP="kvmd"' > /etc/udev/rules.d/99-kvmd-hid.rules
udevadm control --reload 2>/dev/null || true

# 2. drop the old container + configfs gadget + stale symlinks
docker rm -f kvmd 2>/dev/null || true
if [ -d /sys/kernel/config/usb_gadget/kvmd ]; then
    echo "" > /sys/kernel/config/usb_gadget/kvmd/UDC 2>/dev/null || true
    rm -f /sys/kernel/config/usb_gadget/kvmd/configs/c.1/hid.usb0 \
          /sys/kernel/config/usb_gadget/kvmd/configs/c.1/hid.usb1 \
          /sys/kernel/config/usb_gadget/kvmd/configs/c.1/hid.usb2 \
          /sys/kernel/config/usb_gadget/kvmd/configs/c.1/mass_storage.usb0 2>/dev/null || true
    rmdir /sys/kernel/config/usb_gadget/kvmd/functions/hid.usb0 \
          /sys/kernel/config/usb_gadget/kvmd/functions/hid.usb1 \
          /sys/kernel/config/usb_gadget/kvmd/functions/hid.usb2 \
          /sys/kernel/config/usb_gadget/kvmd/functions/mass_storage.usb0 2>/dev/null || true
    rmdir /sys/kernel/config/usb_gadget/kvmd/configs/c.1/strings/0x409 \
          /sys/kernel/config/usb_gadget/kvmd/configs/c.1 \
          /sys/kernel/config/usb_gadget/kvmd/strings/0x409 \
          /sys/kernel/config/usb_gadget/kvmd 2>/dev/null || true
fi
rm -f /dev/hidg* /dev/kvmd-hid-* 2>/dev/null || true

# 3. MSD directory on the host (ISOs survive a container recreate)
mkdir -p /mnt/data/kvmd-msd

# 4. run the container
docker run -d --name kvmd --restart always --privileged \
  -v /dev:/dev \
  -v /lib/modules:/lib/modules \
  -v /sys/kernel/config:/sys/kernel/config \
  -v /mnt/data/kvmd-msd:/var/lib/kvmd/msd \
  -p 4430:4430 -p 5900:5900 -p 623:623/udp -p 8080:8080 \
  -e OTG=1 -e VIDEONUM=1 \
  -e USERNAME="$WEBUSER" \
  -e PASSWORD="$WEBPASS" \
  "$IMAGE" >/dev/null

sleep 30
chown root:kvmd /dev/hidg* 2>/dev/null || true
chmod 0660 /dev/hidg* 2>/dev/null || true

echo "kvmd + OTG ready (web user $WEBUSER)"
docker ps --format '{{.Names}} {{.Status}}'
ls -l /dev/hidg* 2>/dev/null
echo "udc = $(cat /sys/class/udc/musb-hdrc.2.auto/state 2>/dev/null)"
