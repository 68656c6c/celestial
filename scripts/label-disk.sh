#!/usr/bin/env bash
# Give the partitions of an existing install the GPT labels disko expects
# (disk-main-root, disk-main-ESP, disk-main-swap). Run once per machine, as
# root, BEFORE switching to a configuration that uses host.disk, or the next
# boot cannot find its filesystems. No data is touched, only labels.
set -euo pipefail

command -v sgdisk >/dev/null || {
  echo "sgdisk missing, run: sudo nix shell nixpkgs#gptfdisk -c $0" >&2
  exit 1
}
[ "$(id -u)" = 0 ] || { echo "run as root: sudo nix shell nixpkgs#gptfdisk -c $0" >&2; exit 1; }

partition_of() { # <mountpoint or device> -> block device, or nothing
  local src="$1" part
  part="$(findmnt -no SOURCE "$src" 2>/dev/null | sed 's/\[.*//')" || part="$src"
  [ -b "$part" ] || part="$src"
  [ -b "$part" ] && echo "$part"
}

label() { # <device> <label>
  local part="$1" name="$2" disk num
  disk="/dev/$(lsblk -no PKNAME "$part")"
  num="$(lsblk -no PARTN "$part")"
  echo "$part (partition $num of $disk) -> $name"
  sgdisk --change-name="$num:$name" "$disk" >/dev/null
}

root="$(partition_of /)" || { echo "no block device behind /" >&2; exit 1; }
label "$root" disk-main-root

# The ESP by its GPT type on the root disk, not by mountpoint: with
# host.fastboot /boot is only mounted on demand, so findmnt has nothing to say.
disk="/dev/$(lsblk -no PKNAME "$root")"
esp="$(lsblk -no PATH,PARTTYPE "$disk" | awk 'tolower($2) == "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" { print $1; exit }')"
[ -n "$esp" ] || esp="$(partition_of /boot || true)"
if [ -n "$esp" ]; then label "$esp" disk-main-ESP; else echo "skip ESP: none found on $disk" >&2; fi

swap="$(swapon --show=NAME --noheadings | grep -v '^/dev/zram' | head -1 || true)"
[ -n "$swap" ] && label "$swap" disk-main-swap

partprobe 2>/dev/null || true
udevadm settle
echo
ls -l /dev/disk/by-partlabel/disk-main-* 2>/dev/null || echo "no disk-main labels visible yet" >&2
