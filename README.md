# android-tv-community

Community, secret-free rescue/IP-KVM images for Allwinner TV boxes.

Every image here is built from a clean upstream base, contains **no credentials, keys,
Wi-Fi passwords or mesh identities**, and runs a first-boot setup on the device.

## Devices

| Device | Board | Status |
| --- | --- | --- |
| [x96q](x96q/) | X96Q BA301 v1.3 / Allwinner H313 | image in preparation |

## What you get

- Bootable Armbian rescue system on SD.
- One-KVM (video + CH9329 HID) pre-installed.
- NetBird client installed but **unconfigured** (you supply your own setup key).
- Optional exFAT data partition for ISOs and files.

## What you must do after first boot

1. Change the default password.
2. Configure networking (Ethernet is the supported path; Wi-Fi on XR829 is unstable).
3. Optionally join your own NetBird network with your own key.
4. Create the data partition if you want one.

## Safety

- No Android firmware is distributed here. Flashing Android is out of scope.
- Board revisions differ; verify your PCB before writing any image.
- Read each device README for known hardware limitations.

## License / attribution

Images are built on Armbian (see upstream licenses) plus One-KVM and NetBird.
Attribution and exact source revisions are recorded per device README.
