#!/bin/bash
# x96q-firstboot.sh - runs once, on the first boot of the community X96Q image.
#
# It creates a unique machine identity, generates credentials (unless they were
# pre-seeded on the data partition), and creates the kvmd container that provides
# the One-KVM web UI, OTG HID and virtual media.
#
# Optional pre-seed file: /mnt/data/x96q-firstboot.txt
#   HOSTNAME=my-kvm
#   ROOT_PASSWORD=...
#   KVMD_USER=admin
#   KVMD_PASSWORD=...
# Anything left out is generated randomly.
set -u

FLAG=/var/lib/x96q/.firstboot-done
LOG=/var/log/x96q-firstboot.log
CONF=/mnt/data/x96q-firstboot.txt
CRED=/root/.x96q-credentials
KVMD_IMAGE=${KVMD_IMAGE:-registry.cn-hangzhou.aliyuncs.com/silentwind/kvmd:latest}

mkdir -p /var/lib/x96q
log() { echo "$(date -Is) $*" >>"$LOG"; }

[ -f "$FLAG" ] && exit 0

log "=== first boot start ==="

cfg() {
    [ -f "$CONF" ] || return 0
    grep -i "^[[:space:]]*$1[[:space:]]*=" "$CONF" 2>/dev/null | head -1 \
        | cut -d= -f2- | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

gen() { LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16; }

# ---------------------------------------------------------------- 1. identity
: >/etc/machine-id
systemd-machine-id-setup >/dev/null 2>&1 || true
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A >/dev/null 2>&1 || true
rm -f /var/lib/systemd/random-seed
# sshd could not start at boot without host keys - bring it up now
systemctl restart ssh 2>/dev/null || systemctl start ssh 2>/dev/null || true
log "machine-id and SSH host keys regenerated"

# ---------------------------------------------------------------- 2. hostname
HOST=$(cfg HOSTNAME)
HOST=${HOST:-x96q-kvm}
echo "$HOST" >/etc/hostname
if grep -q '^127\.0\.1\.1' /etc/hosts; then
    sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$HOST/" /etc/hosts
else
    printf '127.0.1.1\t%s\n' "$HOST" >>/etc/hosts
fi
hostname "$HOST" 2>/dev/null || true
log "hostname = $HOST"

# ------------------------------------------------------------ 3. credentials
ROOTPASS=$(cfg ROOT_PASSWORD); [ -n "$ROOTPASS" ] || ROOTPASS=$(gen)
KVUSER=$(cfg KVMD_USER);       [ -n "$KVUSER" ]   || KVUSER=admin
KVPASS=$(cfg KVMD_PASSWORD);   [ -n "$KVPASS" ]   || KVPASS=$(gen)

if echo "root:$ROOTPASS" | chpasswd; then
    log "root password set"
else
    log "ERROR: could not set the root password"
fi

umask 077
cat >"$CRED" <<EOC
# X96Q rescue KVM - credentials generated on $(date -Is)
# Delete this file once you have stored the passwords somewhere safe.
ROOT_USER=root
ROOT_PASSWORD=$ROOTPASS
KVMD_USER=$KVUSER
KVMD_PASSWORD=$KVPASS
EOC
chmod 600 "$CRED"
log "credentials written to $CRED"

# ------------------------------------------------------------------- 4. kvmd
if docker image inspect "$KVMD_IMAGE" >/dev/null 2>&1; then
    if WEBUSER="$KVUSER" WEBPASS="$KVPASS" /usr/local/sbin/x96q-kvmd-otg.sh >>"$LOG" 2>&1; then
        log "kvmd container created (OTG HID + MSD)"
    else
        log "ERROR: x96q-kvmd-otg.sh failed - see the log above"
    fi
else
    log "kvmd image not present - skipping container creation"
fi

# ------------------------------------------------------------------- 5. done
date -Is >"$FLAG"
log "=== first boot done ==="
