# android-tv-community

Community, **secret-free** rescue / IP-KVM images for Allwinner TV boxes.

Every image here is built from the author's own working box, then scrubbed and
re-identified: no SSH keys, no Wi-Fi passwords, no NetBird (or other mesh)
identities, no logs, no personal IP addresses, no fixed `machine-id` or SSH host
keys. A first-boot service generates fresh credentials on the device and prints
them on the console.

## Devices

| Device | Board | Image | Status |
| --- | --- | --- | --- |
| [x96q](x96q/) | X96Q BA301 v1.3 / Allwinner H313 | `v0.3` | released |

## What you get (x96q)

- Bootable Armbian Bookworm rescue system on SD (no eMMC, no Android).
- One-KVM (`kvmd`) pre-installed: web UI, **USB OTG HID** (keyboard/mouse) and
  **virtual media** (ISO/IMG over the gadget), plus USB capture-card support.
- Docker image for `kvmd` bundled, so the appliance works offline on first boot.
- NetBird client installed but **not joined** — you supply your own setup key.
- Optional exFAT data partition for ISOs (created by you, on the card).
- Watchdog enabled (16 s) and a Wi-Fi fail-safe for the unstable XR829 radio.

## After first boot

1. Read the generated credentials with `x96q-creds` (they are also printed once
   on the console at first boot).
2. Change both passwords (`passwd`, `x96q-kvmd-password`).
3. Plug Ethernet. Wi-Fi is opt-in and unstable on this board.
4. Optionally join your own NetBird network with your own key.

See [x96q/docs/FIRST-BOOT.md](x96q/docs/FIRST-BOOT.md) and
[x96q/docs/DEPLOY.md](x96q/docs/DEPLOY.md).

## Safety

- No Android firmware is distributed here. Flashing Android / eMMC is out of scope.
- Board revisions differ; verify your PCB before writing any image.
- Only the **USB0** port of the X96Q is a device port. Never connect two hosts
  with an A–A cable.
- Read each device README for known hardware limitations.

## License / attribution

Images are built on [Armbian](https://www.armbian.com/) (GPL-2.0) with
[One-KVM / kvmd](https://github.com/silentwind0/kvmd), Docker, NetBird and the
Linux kernel. Upstream licenses apply to those components. The `kvmd` container
image is embedded for offline use and is redistributed unmodified from
`registry.cn-hangzhou.aliyuncs.com/silentwind/kvmd:latest`; remove or replace it
if you prefer to pull your own. Build scripts and local glue in this repository
are provided under GPL-2.0.
