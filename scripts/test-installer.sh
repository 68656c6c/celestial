#!/usr/bin/env bash
# Try the installer in a VM before trusting it with a machine. Builds the
# image from this checkout, gives the VM an empty disk and a CEL_KEYS
# stick holding the current commit as celestial.bundle, so what gets installed
# is HEAD (commits only, not the working tree), pushed or not.
#
#   scripts/test-installer.sh                     unknown machine: asks for a host name
#   scripts/test-installer.sh "Predator G9-791"   poses as that DMI product: unattended
#   BOOT=disk scripts/test-installer.sh           boot what the last run installed
#
#   VM_DIR      where disk, stick and firmware state live (default /tmp/celestial-vm)
#   STICK_DIR   extra files for the stick, e.g. a directory with keys/<host>.key
#   QEMU_ARGS   appended to the qemu command line
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VM_DIR="${VM_DIR:-/tmp/celestial-vm}"
BOOT="${BOOT:-iso}"
PRODUCT="${1:-}"

if ! command -v qemu-system-x86_64 >/dev/null || ! command -v mcopy >/dev/null || ! command -v mkfs.vfat >/dev/null || ! command -v swtpm >/dev/null; then
  exec nix shell --inputs-from "$REPO_ROOT" nixpkgs#qemu_kvm nixpkgs#mtools nixpkgs#dosfstools nixpkgs#swtpm -c "$0" "$@"
fi

mkdir -p "$VM_DIR"
ovmf="$(nix build --inputs-from "$REPO_ROOT" --no-link --print-out-paths nixpkgs#OVMF.fd)/FV"
args=()

if [ "$BOOT" = iso ]; then
  nix build "$REPO_ROOT#installer-iso" --no-write-lock-file -o "$VM_DIR/iso"
  rm -rf "$VM_DIR/disk.qcow2" "$VM_DIR/vars.fd" "$VM_DIR/stick.img" "$VM_DIR/tpm"
  mkdir -p "$VM_DIR/tpm"
  qemu-img create -q -f qcow2 "$VM_DIR/disk.qcow2" 80G
  install -m 644 "$ovmf/OVMF_VARS.fd" "$VM_DIR/vars.fd"

  truncate -s 512M "$VM_DIR/stick.img"
  mkfs.vfat -n CEL_KEYS "$VM_DIR/stick.img" >/dev/null
  git -C "$REPO_ROOT" bundle create -q "$VM_DIR/celestial.bundle" HEAD "$(git -C "$REPO_ROOT" branch --show-current)"
  mcopy -i "$VM_DIR/stick.img" "$VM_DIR/celestial.bundle" ::
  if [ -n "${STICK_DIR:-}" ]; then mcopy -s -i "$VM_DIR/stick.img" "$STICK_DIR"/* ::; fi

  args+=(-cdrom "$(echo "$VM_DIR"/iso/iso/*.iso)")
  args+=(-drive "if=none,id=stick,format=raw,file=$VM_DIR/stick.img" -device qemu-xhci -device "usb-storage,drive=stick")
fi
[ -z "$PRODUCT" ] || args+=(-smbios "type=1,product=$PRODUCT")

# A TPM 2.0, like the real machines have, for hosts with an encrypted disk
swtpm socket --tpm2 --tpmstate "dir=$VM_DIR/tpm" --ctrl "type=unixio,path=$VM_DIR/tpm/sock" --daemon
args+=(-chardev "socket,id=chrtpm,path=$VM_DIR/tpm/sock" -tpmdev "emulator,id=tpm0,chardev=chrtpm" -device "tpm-tis,tpmdev=tpm0")

# shellcheck disable=SC2086  # QEMU_ARGS is a list of words
exec qemu-system-x86_64 -enable-kvm -machine q35 -cpu host -smp 4 -m 8G \
  -drive "if=pflash,format=raw,readonly=on,file=$ovmf/OVMF_CODE.fd" \
  -drive "if=pflash,format=raw,file=$VM_DIR/vars.fd" \
  -drive "if=virtio,format=qcow2,file=$VM_DIR/disk.qcow2" \
  -nic user,model=virtio-net-pci -vga virtio \
  "${args[@]}" ${QEMU_ARGS:-}
