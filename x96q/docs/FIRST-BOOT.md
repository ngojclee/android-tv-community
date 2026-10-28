# First boot on the X96Q

The image boots into Armbian Bookworm and runs
`x96q-firstboot.service` exactly once. It takes 60–90 s on the first boot
(the `kvmd` container is created at the end).

## What the first boot does

| Step | Result |
| --- | --- |
| machine identity | new `/etc/machine-id`, new SSH host keys, old ones removed |
| hostname | `x96q-kvm` by default |
| credentials | random root password + random `kvmd` web password |
| secrets | `kvmd` container created with those credentials, OTG HID + virtual media |
| log | `/var/log/x96q-firstboot.log` |
| done flag | `/var/lib/x96q/.firstboot-done` |

Nothing personal is baked into the image: the build removes the author's SSH
keys, Wi-Fi PSK, NetBird private key/identity, logs and machine identity, and
verifies the result with a full-image secret scan.

## Reading the credentials

They are printed **once per boot** on a root login (HDMI console or SSH) and are
stored root-only:

```bash
x96q-creds                 # pretty print
sudo cat /root/.x96q-credentials
```

```
X96Q rescue KVM credentials (generated 2026-10-28T09:12:44+00:00)

  console / SSH  :  root / 7fK2...
  One-KVM web UI :  admin / Qm9x...
                    https://<box-ip>:4430/

  change the system password :  passwd
  change the web password    :  x96q-kvmd-password 'new-password'
  credential file            :  /root/.x96q-credentials  (root only, delete when done)
```

Delete the file once you have stored the passwords somewhere safe
(`shred -u /root/.x96q-credentials`).

## Pre-seeding (headless installs)

Create `/x96q-firstboot.txt` in the root of the **data partition** (exFAT,
`RESCUE_DATA`):

```
HOSTNAME=my-kvm
ROOT_PASSWORD=...
KVMD_USER=admin
KVMD_PASSWORD=...
```

Every key is optional. Values must be letters/digits for the kvmd password
(it is passed as a container environment variable).

## Network

- **Ethernet (`end0`)** — DHCP, preferred. Plug the cable before powering on.
- **Wi-Fi (XR829)** — opt-in, 2.4 GHz only, known to be unstable. It is enabled
  only when `/mnt/data/wifi.txt` exists with `ENABLE=1`:

  ```
  SSID=YourNetwork
  PSK=YourPassword
  ENABLE=1
  ```

  A boot-loop fail-safe disables Wi-Fi on the next boot if the previous attempt
  did not get an IP. Keep Ethernet as the primary link.

- **NetBird** — the client is installed and running but **not enrolled**.
  To join your own network:

  ```bash
  echo 'YOUR-SETUP-KEY' > /mnt/data/netbird-setup-key.txt
  systemctl restart x96q-netbird-enroll
  ```

  Or enroll by hand: `netbird up --setup-key ... --hostname my-kvm`.

## Data partition

`/etc/fstab` mounts `LABEL=RESCUE_DATA` at `/mnt/data` with `nofail`, so the box
boots fine without it. Use it for ISOs, images and the preseed/wifi/netbird
files. Create it as described in [DEPLOY.md](DEPLOY.md).

## Disk space

The image has a 5 GiB root with ~2 GiB free. If the card is larger:

```bash
x96q-grow-root.sh          # grows p1 to the end of the card (advanced)
```

It refuses to run when a data partition exists. The clean way is to grow p1 and
create p2 **before** the first boot, on the PC (see DEPLOY.md).

## Useful commands

```bash
systemctl status kvmd docker
docker logs --tail 50 kvmd
journalctl -u x96q-firstboot -b
cat /var/log/x96q-firstboot.log
dmesg | grep -iE 'udc|hidg|uvc|video'
```

## Known limitations

- XR829 Wi-Fi: `missed interrupt` panics under load; cold boot required. Ethernet
  is the supported path. The image keeps the driver blacklisted until opted in.
- Only the **USB0** port is a device port. The other USB-A port is host-only
  (device mode fails with an EP0 stage error — that is the hardware, not a bug).
- Bluetooth does not work in this configuration.
- eMMC/Android boot is not supported: this is an SD-only appliance.
- The captured video device is the MS2130 (`345f:2130`), exposed as
  `/dev/kvmd-video`; the Cedrus VPU decoder (`/dev/video0`) must never be used
  for kvmd's streamer.
