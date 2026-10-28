# X96Q (BA301 v1.3) — community image

Community build of the SD-only rescue / IP-KVM appliance for the X96Q TV box.
Secret-free: the image contains no keys, Wi-Fi passwords, mesh identities or
personal addresses, and generates fresh credentials on the first boot.

Status: **v0.3 released** — see [releases](https://github.com/ngojclee/android-tv-community/releases).

## Target hardware

| Item | Value |
| --- | --- |
| Board | X96Q **BA301 V1.3** |
| SoC | Allwinner H313 (sun50i-h616 / sun50iw9) |
| RAM | 2 GB LPDDR3 |
| SD | 8 GB minimum, 16–32 GB recommended |
| Ethernet | 100 Mbps (`end0`) |
| Wi-Fi | XR829, 2.4 GHz — unstable under Linux, **opt-in only** |
| OTG | **USB0 port only** — HID keyboard/mouse + virtual media |
| USB host | the second USB-A port (host-only, never device mode) |
| Capture | MacroSilicon MS2130 `345f:2130` (optional, for HDMI-in) |

Do **not** use this image on a different board revision without checking the PCB.
The device tree is `sun50i-h313-x96q-lpddr3.dtb` and is patched for this board.

## Image

| Field | Value |
| --- | --- |
| File | `lnc-rescue-kvm-x96q-community-v0.3.img` |
| Uncompressed | 5,372,903,424 bytes = 4 MiB boot header + 5 GiB rootfs |
| SHA256 (`.img`) | `c94dce87a4c122bfe180ff4f281545ba4b59d4204bb64b9c31b6688e286943cc` |
| Compressed | `lnc-rescue-kvm-x96q-community-v0.3.img.gz` — 1,027,757,430 bytes |
| SHA256 (`.gz`) | `a6dec74dbcf2cf544eab7b217714cfceeb045d3e1b7aaee4bbe60cc6c303938a` |
| Base | Armbian 26.02.0-trunk X96Q v1.3, Bookworm, kernel 6.12.64 |
| Rootfs | ext4, 5 GiB, ~2.9 GiB used |
| Boot | SD only. No eMMC, no Android, no `armbian-install`. |

The `.gz` is a single gzip member and expands to the raw image. Verify with
[VERIFY.md](docs/VERIFY.md).

## What is inside

- Armbian Bookworm minimal, DHCP on `end0`, watchdog 16 s.
- Docker + **One-KVM** (`kvmd`) with `hid.type=otg`, `msd.type=otg`,
  ports 4430 (https), 5900 (vnc), 8080 (streamer), 623/udp (ipmi).
- Capture device pinned at container creation (`VIDEONUM=1` → `/dev/video1`), so a
  recreated container never opens the Cedrus VPU decoder (`/dev/video0`);
  `99-x96q-capture.rules` additionally provides `/dev/kvmd-video`.
- Patched device tree (`ehci0`/`ohci0` disabled) so USB0 runs in peripheral mode;
  a service restores the patched DTB after a kernel upgrade.
- Wi-Fi opt-in with a boot-loop fail-safe (`/mnt/data/wifi.txt`).
- NetBird installed, **not enrolled** (`/mnt/data/netbird-setup-key.txt`).
- First-boot service: new machine-id, new SSH host keys, random passwords,
  `kvmd` container creation (`/var/log/x96q-firstboot.log`).
- Helpers: `x96q-creds`, `x96q-kvmd-password`, `x96q-grow-root.sh`.

No personal data: the build script removes the author's SSH key, Wi-Fi PSK,
NetBird identity, logs and machine-id, then scans the whole image and aborts on
any hit. See `build/build-community-image.sh`.

## Getting started

1. [Write the card](docs/DEPLOY.md) (grow the root to 11 GiB first if you can).
2. [First boot](docs/FIRST-BOOT.md) — credentials, network, data partition.
3. [Verify](docs/VERIFY.md) — checksums and the hardware acceptance list.

## Known limitations

- **OTG works only on the USB0 port.** The other USB-A port is host-only; device
  mode fails there with an EP0 stage error. Label USB0 on the case.
- **XR829 Wi-Fi** can panic under load (`missed interrupt`); a cold boot is
  required. Ethernet is the supported path; Wi-Fi is opt-in and has a fail-safe.
- **Bluetooth** does not work in this configuration.
- **eMMC** write path is dead on this board and Android boot is out of scope.
  This is an SD-only appliance; do not run `armbian-install`.
- **5 GiB root** by default (~2 GiB free). Grow p1 to 11 GiB on 16/32 GB cards.
- **Capture** requires an MS2130-class UVC device; the Cedrus decoder is not a
  capture device.

## Build and provenance

| Item | Source |
| --- | --- |
| Armbian base | unofficial build, `BOARD=x96q-v1-3`, `26.02.0-trunk`, kernel 6.12.64 |
| kvmd | `registry.cn-hangzhou.aliyuncs.com/silentwind/kvmd:latest` (embedded, unmodified) |
| Build method | `build/build-community-image.sh` (run on the box), header + MBR from the same base |
| Local glue | remaining scripts in `build/assets/` |

Reproducing: boot any working X96Q v1.3 Armbian build, copy `build/` to
`/root/community-assets`, run the script, then assemble `header + p1` and patch
the MBR entry (`start LBA 8192`, `5 GiB / 10 485 760 sectors`).

## Release checklist

- [x] Built by rsync from a working box, then scrubbed (see `build/`)
- [x] Secrets, logs, histories and caches removed
- [x] SSH host keys and `machine-id` regenerated on first boot
- [x] `e2fsck -fn` clean
- [x] Full-image secret scan (0 hits)
- [x] SHA256 published, `.img.gz` round-trip verified
- [x] Attribution and source revisions recorded
- [ ] Boot test on a freshly written card (pending hardware time)
