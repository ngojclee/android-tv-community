# Writing the X96Q image to an SD card

You need: an SD card (**8 GB minimum**, 16–32 GB recommended), a card reader,
and an image file from the [releases](../../README.md).

> The image is written **raw**, not copied as a file. Etcher, Rufus (DD mode) and
> `dd` all work. This wipes the card.

## 1. Extract (optional)

```bash
gzip -dc lnc-rescue-kvm-x96q-community-v0.3.img.gz > lnc-rescue-kvm-x96q-community-v0.3.img
```

Etcher and Rufus can also open the `.gz` directly — then skip this step.

## 2. Write

**Linux**

```bash
lsblk                                   # find the card, e.g. /dev/sdX - NOT your disk
sudo dd if=lnc-rescue-kvm-x96q-community-v0.3.img of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

**Windows** — open the `.img` (or `.img.gz`) in balenaEtcher and flash. In Rufus
select the card, choose the `.img`, and use *DD image* mode when asked.

## 3. Grow the root filesystem (recommended before the first boot)

The image ships a **5 GiB** root partition. On a 16/32 GB card, grow it to 11 GiB
and give the rest to the data partition. Do this **before** first boot, on the
machine that wrote the card.

**Linux**

```bash
sudo parted -s /dev/sdX unit MiB resizepart 1 11264MiB
sudo partprobe /dev/sdX
sudo e2fsck -f /dev/sdX1
sudo resize2fs /dev/sdX1

sudo parted -s /dev/sdX unit MiB mkpart primary 11268MiB 100%
sudo mkfs.exfat -n RESCUE_DATA /dev/sdX2
```

**Windows** — p1 must be resized before the card is used. Either boot a Linux
live USB for the block above, or keep the 5 GiB root (it works, with ~2 GiB
free) and only create the data partition:

```
diskpart
list disk
select disk N            <- the SD card, check the size twice
list partition
create partition primary
format fs=exfat quick label=RESCUE_DATA
assign
exit
```

If you skipped step 3, you can still grow later on the box itself with
`x96q-grow-root.sh` (it refuses to run when a data partition exists).

## 4. First boot

1. Insert the card, connect **Ethernet**, HDMI (optional) and power.
2. The box takes ~60–90 s: it generates a machine identity and credentials, then
   creates the `kvmd` container.
3. On HDMI the credentials are printed once on the console. Without HDMI, find
   the box on your network and log in over SSH as `root` — the password is
   printed on the console only, so HDMI (or a serial console) is needed for the
   first boot unless you pre-seed credentials.

### Pre-seeding the first boot (headless)

Put a plain-text file named `x96q-firstboot.txt` in the **root of the data
partition** (exFAT, label `RESCUE_DATA`) before booting:

```
HOSTNAME=my-kvm
ROOT_PASSWORD=ChangeMe12345
KVMD_USER=admin
KVMD_PASSWORD=ChangeMeToo1
```

Anything you leave out is generated randomly. A pre-seeded image is only as
secret-free as the card you write it to — change the passwords afterwards.

## 5. One-KVM

Open `https://<box-ip>:4430/` (self-signed certificate), log in with the kvmd
credentials, and connect the target machine's USB and HDMI/capture card.

- **USB0** on the box is the device port (OTG HID + virtual media).
- The other USB-A port is host-only.
- Virtual media appears to the target as a USB drive; put ISOs in
  `/mnt/data` or upload them in the web UI.
