# X96Q (BA301 v1.3) — community image

Status: **in preparation** (no download yet).

## Target hardware

| Item | Value |
| --- | --- |
| Board | X96Q BA301 V1.3 |
| SoC | Allwinner H313 (sun50i-h616) |
| RAM | ~2 GB |
| SD | 32 GB or larger recommended |
| Wi-Fi | XR829 (2.4 GHz) — unstable under Linux, Ethernet recommended |
| HID | CH9329 serial bridge (optional, for KVM input) |
| Capture | MacroSilicon MS2130 USB capture (optional) |

Do **not** use this image on a different board revision without checking the PCB first.

## Planned contents

- Armbian Bookworm minimal (pinned release) — rootfs ~11 GiB.
- Docker + One-KVM (`kvmd`) pre-installed, service enabled.
- NetBird client installed, **not joined** (first-boot asks for your setup key).
- CH9329 udev rule (`/dev/ch9329`) and capture-card notes.
- English first-boot script:
  - set root password
  - choose hostname
  - configure Ethernet (DHCP) and optional Wi-Fi
  - optional NetBird join
  - optional exFAT data partition creation
- No personal logs, histories, SSH host keys or credentials.

## First boot

1. Write the image to an SD card (32 GB+).
2. Insert into the box, power on.
3. Open the console (HDMI or serial) and complete the first-boot prompts.
4. One-KVM UI: `https://<box-ip>:4430/`.

## Known limitations

- OTG device-mode does not attach on this board → no virtual media through USB gadget.
  Use a separate Ventoy USB stick for booting target machines.
- XR829 Wi-Fi can hit `missed interrupt` after long uptime; cold boot is required.
- Bluetooth does not work in the tested Armbian configuration.
- eMMC boot is not part of this image; it is SD-only by design.

## Release checklist (maintainers)

- [ ] Build from clean base, not from a personal clone.
- [ ] Remove secrets, logs, histories, caches, container layers.
- [ ] Regenerate SSH host keys and machine-id.
- [ ] `e2fsck -fn` clean + boot test on hardware.
- [ ] Secret scan + SHA256 published.
- [ ] Attribution and source revisions recorded.
