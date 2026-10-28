# X96Q rescue KVM — community image v0.3

First **public, secret-free** build of the X96Q (BA301 v1.3 / H313) rescue KVM
appliance. Same working system as the author's private v0.3, with every personal
item removed and a first-boot that generates fresh credentials on your device.

## What it is

A 5 GiB Armbian Bookworm image for SD cards that turns an X96Q TV box into a
headless IP-KVM:

- One-KVM web UI on `https://<box-ip>:4430/`
- **USB OTG HID** (keyboard + mouse) and **virtual media** (ISO/IMG) on the USB0 port
- HDMI capture through an MS2130 USB capture card (`/dev/video1`, pinned)
- Ethernet DHCP, optional Wi-Fi (`/mnt/data/wifi.txt`), optional NetBird
- 16 s hardware watchdog

## What is NOT in the image

No SSH keys, no Wi-Fi PSK, no NetBird private key or setup key, no mesh IP, no
private hostname, no shell history, no logs, no fixed `machine-id`, no SSH host
keys. The build removes them and then scans the whole 5 GiB image; it aborts on
any hit. Fresh identity and credentials are created on the first boot.

## Image

| Asset | Size | SHA256 |
| --- | --- | --- |
| `lnc-rescue-kvm-x96q-community-v0.3.img` | 5,372,903,424 bytes | `c94dce87a4c122bfe180ff4f281545ba4b59d4204bb64b9c31b6688e286943cc` |
| `lnc-rescue-kvm-x96q-community-v0.3.img.gz` | 1,027,757,430 bytes | `a6dec74dbcf2cf544eab7b217714cfceeb045d3e1b7aaee4bbe60cc6c303938a` |

`5 372 903 424` bytes uncompressed = 4 MiB boot header + 5 GiB rootfs.
Base: Armbian 26.02.0-trunk, `BOARD=x96q-v1-3`, kernel 6.12.64.

> **Revision 2026-10-28** — the image was rebuilt once before this note was
> finalised. The first upload created the `kvmd` container without `VIDEONUM`, so
> a fresh first boot captured from `/dev/video0` (the Cedrus decoder). Only
> `/usr/local/sbin/x96q-kvmd-otg.sh` differs (one 4 KiB block, same file size);
> every other block is byte-identical to the first upload.

## First boot

1. Write the card ([DEPLOY.md](DEPLOY.md)) — 8 GB minimum, 16–32 GB recommended.
2. Power on with Ethernet. After 60–90 s the console prints the generated
   `root` and One-KVM passwords.
3. `x96q-creds` shows them again; change both, then delete
   `/root/.x96q-credentials`.
4. Headless installs can pre-seed `/x96q-firstboot.txt` on the data partition.

Details: [FIRST-BOOT.md](FIRST-BOOT.md).

## Changes in this build

- v0.3 device tree patch: `ehci0`/`ohci0` disabled so USB0 runs in peripheral
  mode (OTG HID + MSD), restored automatically after a kernel upgrade.
- v0.3 capture fix: the `kvmd` container is created with `VIDEONUM=1`, so its
  first-init rewrites `override.yaml` and `janus.plugin.ustreamer.jcfg` to
  `/dev/video1`; `99-x96q-capture.rules` also provides `/dev/kvmd-video`. A
  recreated container therefore never falls back to the Cedrus VPU decoder
  (`/dev/video0`).
- Community: secrets scrubbed, first-boot service, `x96q-creds`,
  `x96q-kvmd-password`, `x96q-grow-root.sh`, English docs.

## Verification performed

- `e2fsck -fn` clean on the built rootfs (before and after the free-block scrub).
- MBR: `55aa`, p1 type `0x83`, start LBA 8192, 10 485 760 sectors; ext4 magic `53ef`.
- Tree: `x96q-firstboot.service` enabled, `kvmd` OTG script with the capture fix,
  `99-x96q-capture.rules`, patched DTB restore unit, `hostname = x96q-kvm`.
- Absent: `/root/.ssh`, `/etc/ssh/ssh_host_*`, `/etc/wpa.conf`, `/var/lib/netbird`,
  `/etc/netbird`, `/var/lib/containerd`, non-empty `machine-id`.
- Scrubbed tree: full grep with every collected secret — 0 hits.
- Raw image: free space zero-filled, then every *unallocated* block still
  matching a pattern was zeroed (ext4 always keeps a few blocks that `dd`
  cannot reach). Final full-image scan: 0 hits.
- `.img.gz` decompresses to the exact `.img` bytes (round-trip SHA256).

## Known limitations

- USB0 is the only device-capable port; the other USB-A port is host-only.
- XR829 Wi-Fi is unstable and opt-in only; Ethernet is the supported path.
- Bluetooth does not work.
- SD only — the eMMC write path on this board is dead; Android is out of scope.
- The `kvmd` container image is embedded unmodified from the public
  `registry.cn-hangzhou.aliyuncs.com/silentwind/kvmd:latest` registry; its
  upstream license applies.

## Attribution

Armbian (GPL-2.0), Linux 6.12, One-KVM/kvmd, Docker, NetBird, exFAT tools.
Build scripts: `x96q/build/` in this repository.
