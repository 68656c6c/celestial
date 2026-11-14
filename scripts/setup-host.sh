#!/usr/bin/env bash
# Describe the machine this runs on as host <hostname>: hardware file, age key,
# .sops.yaml entry and, for a name that has no folder yet, the per-host files
# filled in from what the hardware reports. The installer runs this for every
# install; run it by hand to convert a machine that already runs NixOS.
#
# Safe to run again: the hardware file is regenerated, an existing age key and
# existing per-host files are kept.
#
#   KEY_DIR   where the age key lives (default /var/lib/sops-nix; the installer
#             points it at a staging directory, the disk is not mounted yet)
set -euo pipefail

HOSTNAME="${1:?Usage: $0 <hostname>}"
[[ "$HOSTNAME" =~ ^[a-z][a-z0-9-]*$ ]] || { echo "not a hostname: $HOSTNAME" >&2; exit 1; }
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_DIR="$REPO_ROOT/system/per_host/$HOSTNAME"
SOPS_FILE="$REPO_ROOT/.sops.yaml"
KEY_DIR="${KEY_DIR:-/var/lib/sops-nix}"

as_root() { if [ "$(id -u)" = 0 ]; then "$@"; else sudo "$@"; fi; }

write_new() { # <file>, content on stdin; never overwrites
  if [ -e "$1" ]; then echo "    keeping $1"; cat >/dev/null; else cat >"$1"; fi
}

age_keygen() {
  if command -v age-keygen >/dev/null; then
    as_root age-keygen "$@"
  else
    as_root nix --extra-experimental-features "nix-command flakes" shell nixpkgs#age -c age-keygen "$@"
  fi
}

# What the hardware says about itself
RELEASE="$(nixos-version 2>/dev/null | cut -d. -f1-2)"
: "${RELEASE:=26.05}"

PRODUCT="$(sed 's/[[:space:]]*$//' /sys/class/dmi/id/product_name 2>/dev/null || true)"

gpu_vendors="$(cat /sys/class/drm/card[0-9]*/device/vendor 2>/dev/null || true)"
case "$gpu_vendors" in
  *0x8086*) GPU=intel ;; # with an nvidia card next to it too: the desktop runs on the iGPU
  *0x1002*) GPU=amd ;;
  *0x10de*) GPU=nvidia ;;
  *) GPU= ;;
esac

LAPTOP=false
compgen -G '/sys/class/power_supply/BAT*' >/dev/null && LAPTOP=true

AMD_CPU=false
grep -qm1 AuthenticAMD /proc/cpuinfo 2>/dev/null && AMD_CPU=true

MONITORS=""
for status in /sys/class/drm/card*-*/status; do
  [ -e "$status" ] && [ "$(cat "$status")" = connected ] || continue
  connector="$(basename "$(dirname "$status")")"
  mode="$(head -1 "$(dirname "$status")/modes" 2>/dev/null || true)"
  [[ "$mode" =~ ^([0-9]+)x([0-9]+) ]] || continue
  MONITORS+="    {
      output = \"${connector#card*-}\";
      width = ${BASH_REMATCH[1]};
      height = ${BASH_REMATCH[2]};
    }
"
done

echo "==> $HOSTNAME: ${PRODUCT:-unknown product}, gpu ${GPU:-not recognised}, laptop $LAPTOP"

echo "==> Generating hardware config..."
mkdir -p "$HOST_DIR"
HARDWARE_FILE="$HOST_DIR/hardware-configuration.$HOSTNAME.nix"
as_root nixos-generate-config --no-filesystems --show-hardware-config >"$HARDWARE_FILE.new"
mv "$HARDWARE_FILE.new" "$HARDWARE_FILE"
# What `nix flake check` wants: no unused arguments (the generator always
# writes `pkgs`) and the formatting of `nix fmt`, so an unchanged machine
# gives no diff and a new one does not turn CI red.
if command -v deadnix >/dev/null; then deadnix --edit --no-lambda-arg "$HARDWARE_FILE" >/dev/null; fi
if command -v nixfmt >/dev/null; then nixfmt "$HARDWARE_FILE"; fi

echo "==> Age key..."
as_root mkdir -p "$KEY_DIR"
if as_root test -s "$KEY_DIR/key"; then
  echo "    keeping the existing key"
else
  age_keygen -o "$KEY_DIR/key" 2>/dev/null
fi
as_root chmod 600 "$KEY_DIR/key"
PUBKEY="$(age_keygen -y "$KEY_DIR/key")"

echo "==> $HOSTNAME in .sops.yaml..."
if grep -q "&host_$HOSTNAME $PUBKEY\$" "$SOPS_FILE"; then
  echo "    already listed"
elif grep -q "&host_$HOSTNAME " "$SOPS_FILE"; then
  # A different key is listed (reinstalled without the old key). Left alone,
  # the host would count as enrolled and wait for a password it cannot decrypt.
  echo "    replacing the key that was listed"
  sed -i "s|^\(  - &host_$HOSTNAME \).*|\1$PUBKEY|" "$SOPS_FILE"
else
  sed -i "/^  - &backup /i\\  - &host_$HOSTNAME $PUBKEY" "$SOPS_FILE"
  sed -i "/^  all: &all$/a\\    - *host_$HOSTNAME" "$SOPS_FILE"
fi

# secrets.yaml lists the keys it is encrypted for. Until this one is among them
# (scripts/rekey.sh on an enrolled machine) the login password cannot come from
# the secrets, so the host reads it from a file next to the key instead.
ENROLLED=false
grep -q "$PUBKEY" "$REPO_ROOT/secrets/secrets.yaml" && ENROLLED=true
if [ "$ENROLLED" = false ] && ! as_root test -s "$KEY_DIR/password"; then
  echo "==> This key cannot read the secrets yet, so the login password is set here."
  [ -t 0 ] || { echo "no terminal to ask for a password on" >&2; exit 1; }
  while :; do
    read -r -s -p "    password for artesia: " first; echo
    read -r -s -p "    once more: " second; echo
    if [ -n "$first" ] && [ "$first" = "$second" ]; then break; fi
    echo "    empty or not the same, try again"
  done
  printf '%s' "$first" | mkpasswd -m yescrypt -s | as_root tee "$KEY_DIR/password" >/dev/null
  as_root chmod 600 "$KEY_DIR/password"
  unset first second
fi

write_new "$HOST_DIR/default.nix" << EOF
{ ... }:

{
  imports = [
    ./${HOSTNAME}_packages.nix
    ./${HOSTNAME}_configurations.nix
    ./${HOSTNAME}_programs.nix
    ./${HOSTNAME}_services.nix
  ];
}
EOF

DMI_LINE="host.dmi = [ ];"
[ -n "$PRODUCT" ] && DMI_LINE="host.dmi = [ \"$PRODUCT\" ];"
GPU_LINE="# host.gpu = \"intel\"; # intel, amd or nvidia; none recognised"
[ -n "$GPU" ] && GPU_LINE="host.gpu = \"$GPU\";"
MONITORS_BLOCK="host.monitors = [ ];"
[ -n "$MONITORS" ] && MONITORS_BLOCK="host.monitors = [
$MONITORS  ];"
LAPTOP_BLOCK="host.laptop.enable = $LAPTOP;"
[ "$LAPTOP" = true ] && [ "$AMD_CPU" = true ] && LAPTOP_BLOCK="host.laptop = {
    enable = true;
    thermald = false; # AMD
  };"

write_new "$HOST_DIR/${HOSTNAME}_configurations.nix" << EOF
{ ... }:

{
  networking.hostName = "$HOSTNAME";
  $DMI_LINE
  $GPU_LINE
  host.fastboot.enable = true;
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];

  $MONITORS_BLOCK

  $LAPTOP_BLOCK

  # Release this machine was first installed with. Leave it alone.
  system.stateVersion = "$RELEASE";
  home-manager.users.artesia.home.stateVersion = "$RELEASE";
}
EOF

write_new "$HOST_DIR/${HOSTNAME}_packages.nix" << EOF
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
  ];
}
EOF

write_new "$HOST_DIR/${HOSTNAME}_programs.nix" << EOF
{ ... }:

{
  programs = {
    # compositor: niri with noctalia, or sway.enable = true
    niri.enable = true;
    noctalia.enable = true;
  };
}
EOF

write_new "$HOST_DIR/${HOSTNAME}_services.nix" << EOF
{ ... }:

{
  services = {
  };
}
EOF

# flakes only see files git knows about
git -C "$REPO_ROOT" add --intent-to-add "$HOST_DIR" 2>/dev/null || true

echo
echo "host:        $HOSTNAME"
echo "public key:  $PUBKEY"
if [ "$ENROLLED" = true ]; then
  echo "secrets:     readable with this key"
else
  echo "secrets:     not readable yet, login uses the password just set"
  echo "             to hand over: commit and push, then on an enrolled machine"
  echo "             git pull && scripts/rekey.sh, and switch here again"
fi

# Converting a running machine (the installer partitions and labels by itself)
if [ "$KEY_DIR" = /var/lib/sops-nix ] && [ ! -e /dev/disk/by-partlabel/disk-main-root ]; then
  echo
  echo "This install mounts by UUID. Before the first switch to $HOSTNAME:"
  echo "  sudo nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#gptfdisk -c scripts/label-disk.sh"
  echo "and set host.disk.layout to the filesystem the root really has."
fi
