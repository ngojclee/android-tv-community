# Verifying the image

## Integrity

Download `SHA256SUMS` and the `.img.gz` from the same release, then:

**Linux / macOS**

```bash
sha256sum -c SHA256SUMS
```

**Windows**

```powershell
Get-FileHash .\lnc-rescue-kvm-x96q-community-v0.3.img.gz -Algorithm SHA256
# compare with SHA256SUMS
```

The release page also shows the SHA256 of each asset (GitHub digest).

## Before the first boot (optional, on the PC)

```bash
gzip -dc lnc-rescue-kvm-x96q-community-v0.3.img.gz > x96q.img
ls -l x96q.img                     # 5 372 903 424 bytes
sudo e2fsck -fn /dev/sdX1          # clean after writing the card
```

`e2fsck -fn` must report a clean filesystem (it may report "clean" on the first
pass after a fresh mkfs; no errors are expected).

## What "no secrets" means here

The build (`x96q/build/build-community-image.sh`) removes and then scans for:

- the author's SSH public key (from `authorized_keys`)
- the Wi-Fi PSK and SSID (from the build box's `wifi.txt`)
- the NetBird private key, setup key and management URL
- a local list of extra strings that stays on the build box
  (`/root/.x96q-extra-secrets`: the previous kvmd web password, the SSID, the
  mesh and Wi-Fi addresses, the previous hostname). The values are never
  written into this repository.
- `/etc/ssh/ssh_host_*`, `/etc/machine-id`, shell history, logs (`/var/log`,
  `/var/log.hdd`), `/var/lib/containerd`, runtime state

Scrubbing a file is not enough on ext4: `rm` only frees blocks, it does not
erase them, and `dd`-filling the free space always leaves a few blocks that the
filesystem keeps for metadata growth. The build therefore:

1. greps the scrubbed tree (must be 0 hits, else it aborts),
2. zero-fills the free space,
3. greps the whole raw image and **zeroes every unallocated block that still
   matches**, aborting if a match sits in a live block,
4. repeats the full-image scan until it is 0 hits, then `e2fsck -fn`.

You can repeat the final check yourself:

```bash
# put the strings you care about in patterns.txt, one per line, then:
grep -ac -f patterns.txt x96q.img   # -> 0
```

## Hardware acceptance checklist (X96Q BA301 v1.3)

| # | Check | Expected |
| --- | --- | --- |
| 1 | Boot from SD with HDMI | Armbian console, `x96q-creds` message |
| 2 | Ethernet DHCP | `ip -4 addr show end0` has an address |
| 3 | `systemctl status docker kvmd` | `active (running)` |
| 4 | `https://<ip>:4430/` | login page, web credentials work |
| 5 | OTG: plug USB0 into a PC | HID keyboard appears, keys work in Notepad |
| 6 | Virtual media | ISO appears as a USB drive to the target |
| 7 | Capture card (MS2130) | `ls -l /dev/kvmd-video`, snapshot returns a JPEG |
| 8 | Reboot | credentials unchanged, container comes back by itself |
| 9 | `ls /dev/mmcblk2` | eMMC is never written by this image |

Items 5–7 need the USB0 port, a capture card and a target machine.
