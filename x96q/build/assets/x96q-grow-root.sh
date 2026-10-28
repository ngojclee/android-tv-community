#!/bin/bash
# x96q-grow-root.sh [size-in-MiB]
#
# Grows partition 1 (the root filesystem) to the end of the card, or to an
# explicit size in MiB. Refuses to run if p1 is not the last partition, so it
# can never eat a data partition.
#
# The official recommendation is to grow BEFORE the first boot (see docs/DEPLOY.md).
# This helper exists for cards that were written as-is.
#
# ADVANCED: it edits the partition table of the running (mounted) card.
set -euo pipefail

DISK=${DISK:-/dev/mmcblk0}
PART=${DISK}p1
SIZE_MIB=${1:-}

[ "$(id -u)" = 0 ] || { echo "run as root"; exit 1; }
[ "$(lsblk -ln -o NAME "$DISK" | tail -1)" = "$(basename "$PART")" ] || {
    echo "$PART is not the last partition on $DISK - refusing (a data partition exists)."
    exit 1
}

if [ -z "$SIZE_MIB" ]; then
    SIZE_MIB=$(( $(blockdev --getsize64 "$DISK") / 1024 / 1024 - 1 ))
fi

CUR=$(parted -sm "$DISK" unit MiB print | awk -F: '$1=="1"{print $2}')
CUR=${CUR%MiB}
if [ "${CUR%.*}" -ge "$SIZE_MIB" ] 2>/dev/null; then
    echo "p1 already spans ${CUR}MiB - nothing to do"
    exit 0
fi

echo "resizing p1: ${CUR}MiB -> ${SIZE_MIB}MiB on $DISK"
parted -s "$DISK" unit MiB resizepart 1 "${SIZE_MIB}MiB"
partprobe "$DISK" 2>/dev/null || true
partx -u "$DISK" 2>/dev/null || true
resize2fs "$PART"
df -h /
echo "done. If resize2fs refused, reboot and run: resize2fs $PART"
