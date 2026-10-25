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

label() { # <mountpoint or device> <label>
  local src="$1" name="$2" part disk num
  part="$(findmnt -no SOURCE "$src" 2>/dev/null | sed 's/\[.*//')" || part="$src"
  [ -b "$part" ] || part="$src"
  [ -b "$part" ] || { echo "skip $src: no block device" >&2; return 0; }
  disk="/dev/$(lsblk -no PKNAME "$part")"
  num="$(lsblk -no PARTN "$part")"
  echo "$part (partition $num of $disk) -> $name"
  sgdisk --change-name="$num:$name" "$disk" >/dev/null
}

label / disk-main-root
label /boot disk-main-ESP
swap="$(swapon --show=NAME --noheadings | grep -v '^/dev/zram' | head -1 || true)"
[ -n "$swap" ] && label "$swap" disk-main-swap

partprobe 2>/dev/null || true
udevadm settle
echo
ls -l /dev/disk/by-partlabel/ | grep disk-main
