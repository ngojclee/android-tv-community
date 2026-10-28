#!/bin/bash
# build-community-image.sh
#
# Builds the secret-free community root filesystem from a RUNNING X96Q box.
# Run it as root on the box itself (it reads the live system and writes only to
# /root - it never touches /dev/mmcblk0).
#
#   scp -r x96q/build/assets root@<box>:/root/community-assets
#   ssh root@<box> 'bash /root/community-assets/build-community-image.sh'
#
# Output: /root/community-p1.img (5 GiB) and /root/community-p1.img.gz
set -u

IMG=${IMG:-/root/community-p1.img}
MNT=${MNT:-/mnt/newsys}
ASSETS=${ASSETS:-/root/community-assets}
LOG=${LOG:-/root/build-community.log}
PAT=/root/.x96q-secret-patterns
PATVAL=/root/.x96q-secret-values

exec > >(tee -a "$LOG") 2>&1
log() { echo "[$(date +%H:%M:%S)] $*"; }
die() { log "FATAL: $*"; exit 1; }

[ "$(id -u)" = 0 ] || die "run as root"
[ -d "$ASSETS" ] || die "assets directory $ASSETS not found"
[ -x "$ASSETS/x96q-firstboot.sh" ] || die "$ASSETS/x96q-firstboot.sh missing"

# ------------------------------------------------------- 0. exact secret values
log "== collecting the exact secret values to scan for later =="
: >"$PAT"
: >"$PATVAL"
chmod 600 "$PAT" "$PATVAL"
# addpat <description> <value>   (values are never printed)
addpat() {
    [ "${#2}" -ge 6 ] || return 0
    printf '%s\t%s\n' "$1" "$2" >>"$PAT"
    printf '%s\n' "$2" >>"$PATVAL"
}
addpat "SSH public key"        "$(awk 'NF>2{print $2}' /root/.ssh/authorized_keys 2>/dev/null | head -1)"
addpat "Wi-Fi PSK"             "$(grep -i '^PSK=' /mnt/data/wifi.txt 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r' | sed 's/^ *//;s/ *$//')"
addpat "NetBird private key"   "$(python3 -c "import json;print(json.load(open('/var/lib/netbird/default.json')).get('PrivateKey',''))" 2>/dev/null)"
addpat "NetBird setup key"     "$(tr -d ' \t\r\n' </mnt/data/netbird-setup-key.txt 2>/dev/null)"
# Board-local strings that do not live in a file: the old kvmd web password, the
# Wi-Fi SSID, the NetBird management URL, the mesh / Wi-Fi addresses, the old
# hostname. Keep them on the box only - never in this repository:
#   umask 077; cat >/root/.x96q-extra-secrets   # one value per line
while IFS= read -r v; do
    case "$v" in ''|'#'*) continue ;; esac
    addpat "extra local value" "$v"
done </root/.x96q-extra-secrets 2>/dev/null
log "   $(wc -l <"$PAT") patterns (values are not printed)"

# --------------------------------------------------------------- 1. park state
log "== stopping stateful services =="
docker rm -f kvmd >/dev/null 2>&1 || true
systemctl stop docker.socket docker containerd 2>/dev/null || true
systemctl stop netbird 2>/dev/null || true
sleep 2

# ------------------------------------------------------------------ 2. new fs
log "== creating the 5 GiB ext4 filesystem =="
umount "$MNT" 2>/dev/null || true
rm -f "$IMG" "$IMG.gz"
FREE=$(df -Pk /root | awk 'NR==2{print $4}')
[ "$FREE" -gt $((6 * 1024 * 1024)) ] || die "need 6 GiB free on /root, have $((FREE / 1024)) MiB"
truncate -s 5G "$IMG" || die "truncate failed"
mkfs.ext4 -F -L armbi_root -m 1 "$IMG" >/dev/null || die "mkfs failed"
mkdir -p "$MNT"
mount -o loop "$IMG" "$MNT" || die "loop mount failed"

# ------------------------------------------------------------------- 3. rsync
log "== rsync / -> $MNT (excluding runtime state) =="
rsync -aHAXx --numeric-ids / "$MNT"/ \
    --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run --exclude=/tmp \
    --exclude=/mnt/newsys --exclude=/mnt/data \
    --exclude=/root/community-assets \
    --exclude=/root/community-p1.img \
    --exclude=/root/community-p1.img.gz \
    --exclude=/root/.x96q-secret-patterns \
    --exclude=/root/.x96q-secret-values \
    --exclude=/root/restore-kvmd.log \
    --exclude=/root/spd.bin \
    --exclude=/var/log/journal \
    --exclude=/var/lib/docker/containers \
    --exclude=/var/cache/apt/archives
log "   rsync done ($(du -sh "$MNT" | cut -f1))"

S=$MNT
log "== scrubbing personal state =="
# identity / shell / build leftovers
rm -rf "$S"/root/.ssh "$S"/root/.config "$S"/root/.cache "$S"/root/.bash_history "$S"/root/.lesshst \
       "$S"/root/.viminfo
rm -f "$S"/root/build-image-v2.sh "$S"/root/build-image-v3.sh "$S"/root/build-v03.log \
      "$S"/root/dtb.orig "$S"/root/make-dtb.py "$S"/root/x96q-provision.sh \
      "$S"/root/*.img "$S"/root/*.img.gz
# ssh + machine identity
rm -f "$S"/etc/ssh/ssh_host_*
: >"$S"/etc/machine-id
rm -f "$S"/var/lib/dbus/machine-id
ln -sf /etc/machine-id "$S"/var/lib/dbus/machine-id
rm -f "$S"/var/lib/systemd/random-seed "$S"/var/lib/systemd/credential.secret
# netbird (keys, mesh IP, private management URL)
rm -rf "$S"/var/lib/netbird "$S"/etc/netbird
# wifi credentials
rm -f "$S"/etc/wpa.conf
rm -rf "$S"/etc/NetworkManager/system-connections
# runtime state and logs
rm -rf "$S"/var/lib/x96q/* "$S"/var/log/* "$S"/tmp/* "$S"/var/tmp/*
rm -rf "$S"/var/log.hdd            # old log tree from the previous SD layout
rm -rf "$S"/var/lib/containerd     # rebuilt empty by containerd at boot (old container env)
mkdir -p "$S"/var/log "$S"/tmp "$S"/var/tmp
chmod 755 "$S"/var/log; chmod 1777 "$S"/tmp "$S"/var/tmp
rm -rf "$S"/var/cache/apt/archives/*.deb
# leftovers of earlier patching (they still carry the author's default web password)
rm -f "$S"/usr/local/sbin/x96q-kvmd-otg.sh.bak "$S"/usr/local/sbin/x96q-kvmd-otg.sh.new

# ------------------------------------------------------------ 4. fresh identity
log "== hostname + motd =="
echo "x96q-kvm" >"$S"/etc/hostname
sed -i 's/^127\.0\.1\.1.*/127.0.1.1\tx96q-kvm/' "$S"/etc/hosts
# the build box's own hostname must not survive anywhere under /etc
# (pass it as OLD_HOSTNAME=... ; the secret scan below fails the build if it does)
if [ -n "${OLD_HOSTNAME:-}" ]; then
    grep -rlZ -- "$OLD_HOSTNAME" "$S"/etc 2>/dev/null |
        xargs -0 -r sed -i "s|$OLD_HOSTNAME|x96q-kvm|g"
fi
# stock Armbian also lists BOARD (x96q-v1-3) on the ::1 line - normalise it
sed -i 's/^::1[[:space:]].*/::1\tlocalhost ip6-localhost ip6-loopback/' "$S"/etc/hosts
rm -f "$S"/etc/motd
cat >"$S"/etc/motd <<'EOM'

 X96Q rescue KVM - community image

  * first-boot credentials .... x96q-creds
  * network ................... DHCP on end0 (Ethernet); Wi-Fi is opt-in
                                (/mnt/data/wifi.txt, XR829 is unstable)
  * data partition ............ LABEL=RESCUE_DATA -> /mnt/data (optional)
  * web UI .................... https://<box-ip>:4430/
  * grow the root fs .......... x96q-grow-root.sh (read the docs first)

 Only the USB0 port is a device port (OTG HID + virtual media).
 The other USB-A port is host-only.

EOM

log "== installing first-boot units =="
install -m 0755 "$ASSETS/x96q-firstboot.sh"            "$S"/usr/local/sbin/
install -m 0755 "$ASSETS/x96q-creds"                   "$S"/usr/local/sbin/
install -m 0755 "$ASSETS/x96q-kvmd-password"           "$S"/usr/local/sbin/
install -m 0755 "$ASSETS/x96q-grow-root.sh"            "$S"/usr/local/sbin/
install -m 0755 "$ASSETS/x96q-kvmd-otg.sh"             "$S"/usr/local/sbin/
install -m 0644 "$ASSETS/x96q-firstboot.service"       "$S"/etc/systemd/system/
install -m 0644 "$ASSETS/x96q-credentials-notice.sh"   "$S"/etc/profile.d/
ln -sf /etc/systemd/system/x96q-firstboot.service \
      "$S"/etc/systemd/system/multi-user.target.wants/x96q-firstboot.service

# ------------------------------------------------------- 5. fstab + armbianEnv
log "== fixing fstab UUID and armbianEnv rootdev =="
NEWUUID=$(blkid -s UUID -o value "$IMG")
log "   new UUID = $NEWUUID"
sed -i "s|^UUID=[^ ]* / ext4|UUID=$NEWUUID / ext4|" "$S"/etc/fstab
sed -i "s|^rootdev=.*|rootdev=UUID=$NEWUUID|" "$S"/boot/armbianEnv.txt
grep -q configfs "$S"/etc/fstab || \
    echo "configfs /sys/kernel/config configfs defaults 0 0" >>"$S"/etc/fstab

# -------------------------------------------------------------- 6. verify tree
log "== verifying the tree =="
FAIL=0
for p in sbin/init usr/lib/systemd/systemd etc/passwd etc/shadow etc/fstab etc/hostname \
         boot/Image boot/boot.scr boot/armbianEnv.txt \
         etc/systemd/system/x96q-firstboot.service \
         etc/systemd/system/multi-user.target.wants/x96q-firstboot.service \
         usr/local/sbin/x96q-firstboot.sh usr/local/sbin/x96q-creds \
         usr/local/sbin/x96q-kvmd-otg.sh \
         etc/systemd/system/x96q-dtb-fix.service \
         etc/systemd/system/x96q-wifi-config.service \
         etc/systemd/system/x96q-netbird-enroll.service \
         etc/udev/rules.d/99-x96q-capture.rules \
         usr/local/sbin/otg-phy-fix.sh \
         etc/modprobe.d/blacklist-xradio.conf \
         etc/systemd/system/getty@tty1.service.d/autologin.conf; do
    if [ -e "$S/$p" ] || [ -L "$S/$p" ]; then echo "   OK   $p"; else echo "   MISSING $p"; FAIL=1; fi
done
[ "$FAIL" = 0 ] || die "tree verification failed"

log "== checking that the scrub worked =="
for p in root/.ssh etc/ssh/ssh_host_ed25519_key etc/wpa.conf var/lib/netbird/default.json \
         etc/netbird var/lib/x96q/.firstboot-done; do
    [ -e "$S/$p" ] && { echo "   STILL PRESENT: $p"; FAIL=1; }
done
[ "$FAIL" = 0 ] || die "scrub verification failed"
grep -q '^UUID=' "$S"/etc/fstab && grep -q "rootdev=UUID=$NEWUUID" "$S"/boot/armbianEnv.txt \
    || die "fstab/armbianEnv mismatch"
[ -s "$S"/etc/machine-id ] && die "machine-id is not empty"
grep -q '^root:!' "$S"/etc/shadow || log "   note: root is not locked in the image (first boot sets a password)"

log "== locating leftover patterns in the tree (fast, shows file paths) =="
HITS=$(grep -rlaF -f "$PATVAL" "$S" 2>/dev/null | sed "s|^$S|   |" | head -30)
if [ -n "$HITS" ]; then
    echo "$HITS"
    die "the scrubbed tree still contains personal data - fix the scrub above"
fi
log "   no pattern left in any file of the tree"

sync
log "== zeroing the free space (stale blocks of deleted/replaced files) =="
dd if=/dev/zero of="$S"/.zerofill bs=4M 2>/dev/null || true
sync
rm -f "$S"/.zerofill
sync
umount "$S" || die "umount failed"
log "== e2fsck -fy =="
e2fsck -fy "$IMG" 2>&1 | tail -3

# ------------------------------------------------------------ 7. secret scan
# A freshly formatted ext4 always keeps a few free blocks that `dd` cannot reach
# (space reserved for metadata growth). Old file contents can survive there, so
# the scan does not just look: it zeroes every *unallocated* block that still
# matches a pattern, and refuses to run if a match sits in a live block.
log "== full-image secret scan + free-block scrub (this takes a few minutes) =="
MAXLEN=$(awk '{ if (length($0) > m) m = length($0) } END { print (m ? m : 64) }' "$PATVAL")
CLEAN=0
for pass in 1 2 3; do
    OFF=$(grep -aboF -f "$PATVAL" "$IMG" 2>/dev/null | cut -d: -f1 | sort -nu)
    if [ -z "$OFF" ]; then
        log "   pass $pass: clean - no pattern anywhere in the image"
        CLEAN=1
        break
    fi
    log "   pass $pass: $(echo "$OFF" | wc -l) hit(s) in leftover blocks - zeroing"
    BLK=""
    for o in $OFF; do
        for ((b = o / 4096; b <= (o + MAXLEN) / 4096; b++)); do BLK="$BLK $b"; done
    done
    for b in $(echo "$BLK" | tr ' ' '\n' | sort -nu); do
        INO=$(debugfs -R "icheck $b" "$IMG" 2>/dev/null | awk 'NR==2{print $2}')
        case "$INO" in
            ''|*[!0-9]*)
                dd if=/dev/zero of="$IMG" bs=4096 count=1 seek="$b" conv=notrunc 2>/dev/null
                ;;
            *)
                die "a secret is still inside allocated block $b (inode $INO)"
                ;;
        esac
    done
done
[ "$CLEAN" = 1 ] || die "the image is still dirty after 3 passes"
sync
log "== e2fsck -fn after zeroing =="
e2fsck -fn "$IMG" 2>&1 | tail -3

# ---------------------------------------------------------------- 8. compress
log "== gzip -6 =="
gzip -6 -c "$IMG" >"$IMG.gz" || die "gzip failed"
sync
ls -l "$IMG" "$IMG.gz"
sha256sum "$IMG" "$IMG.gz" | tee /root/community-p1.sha256
rm -f "$PAT" "$PATVAL"
log "== DONE =="
log "   pull these two files, then assemble the bootable image on the PC"
