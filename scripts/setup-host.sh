#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="${1:?Usage: $0 <hostname>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_DIR="$REPO_ROOT/system/per_host/$HOSTNAME"
SOPS_FILE="$REPO_ROOT/.sops.yaml"

# Safe to run again: the hardware file is regenerated, an existing age key and
# existing per-host files are kept.
write_new() { # <file>, content on stdin; never overwrites
  if [ -e "$1" ]; then echo "    keeping $1"; cat >/dev/null; else cat >"$1"; fi
}

age_keygen() {
  if command -v age-keygen >/dev/null; then sudo age-keygen "$@"; else sudo nix shell nixpkgs#age -c age-keygen "$@"; fi
}

RELEASE="$(nixos-version 2>/dev/null | cut -d. -f1-2)"
: "${RELEASE:=26.05}"

PRODUCT="$(sed 's/[[:space:]]*$//' /sys/class/dmi/id/product_name 2>/dev/null || true)"

echo "==> Generating hardware config..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
sudo nixos-generate-config --no-filesystems --dir "$TMP_DIR"
mkdir -p "$HOST_DIR"
mv "$TMP_DIR/hardware-configuration.nix" "$HOST_DIR/hardware-configuration.$HOSTNAME.nix"
sudo chown "$(id -u):$(id -g)" "$HOST_DIR/hardware-configuration.$HOSTNAME.nix"

echo "==> Generating sops age key..."
sudo mkdir -p /var/lib/sops-nix
if sudo test -s /var/lib/sops-nix/key; then
  echo "    keeping the existing key"
else
  age_keygen -o /var/lib/sops-nix/key
fi
sudo chmod 600 /var/lib/sops-nix/key
PUBKEY=$(age_keygen -y /var/lib/sops-nix/key)

echo "==> Adding $HOSTNAME to .sops.yaml..."
if grep -q "&host_$HOSTNAME " "$SOPS_FILE"; then
  echo "    already listed"
else
  sed -i "/^  - &backup /i\\  - &host_$HOSTNAME $PUBKEY" "$SOPS_FILE"
  sed -i "/^  all: &all$/a\\    - *host_$HOSTNAME" "$SOPS_FILE"
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

write_new "$HOST_DIR/${HOSTNAME}_configurations.nix" << EOF
{ ... }:

{
  networking.hostName = "$HOSTNAME";
  host.dmi = [ "$PRODUCT" ];
  host.disk.layout = "btrfs";
  host.gpu = "intel"; # intel, amd or nvidia
  networking.nameservers = [
  ];

  host.monitors = [
  ];

  host.laptop.enable = false;
  host.fastboot.enable = false;

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

echo "public key: $PUBKEY"
echo "1. dns, monitors and host.laptop in $HOST_DIR/${HOSTNAME}_configurations.nix"
echo "2. re-encrypt secrets with: sops updatekeys secrets/secrets.yaml"
echo "3. after the first switch, join the tailnet by hand: sudo tailscale up"
echo "4. this install mounts by UUID; run scripts/label-disk.sh before switching to the new host folder"
