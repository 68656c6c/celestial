#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="${1:?Usage: $0 <hostname>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_DIR="$REPO_ROOT/system/per_host/$HOSTNAME"
SOPS_FILE="$REPO_ROOT/.sops.yaml"

if [ -d "$HOST_DIR" ]; then
  echo "Error: $HOST_DIR already exists" >&2
  exit 1
fi

RELEASE="$(nixos-version 2>/dev/null | cut -d. -f1-2)"
: "${RELEASE:=26.05}"

echo "==> Generating hardware config..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
sudo nixos-generate-config --dir "$TMP_DIR"
mkdir -p "$HOST_DIR"
mv "$TMP_DIR/hardware-configuration.nix" "$HOST_DIR/hardware-configuration.$HOSTNAME.nix"
sudo chown "$(id -u):$(id -g)" "$HOST_DIR/hardware-configuration.$HOSTNAME.nix"

echo "==> Generating sops age key..."
sudo mkdir -p /var/lib/sops-nix
sudo age-keygen -o /var/lib/sops-nix/key 2>/dev/null
sudo chmod 600 /var/lib/sops-nix/key
PUBKEY=$(sudo age-keygen -y /var/lib/sops-nix/key)

echo "==> Adding $HOSTNAME to .sops.yaml..."
sed -i "/^  - &backup /i\\  - &host_$HOSTNAME $PUBKEY" "$SOPS_FILE"
sed -i "/^  all: &all$/a\\    - *host_$HOSTNAME" "$SOPS_FILE"

cat > "$HOST_DIR/default.nix" << EOF
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

cat > "$HOST_DIR/${HOSTNAME}_configurations.nix" << EOF
{
  config,
  pkgs,
  ...
}:

{
  networking.hostName = "$HOSTNAME";
  networking.nameservers = [
  ];

  host.monitors = [
  ];

  host.laptop.enable = false;

  # Release this machine was first installed with. Leave it alone.
  system.stateVersion = "$RELEASE";
  home-manager.users.artesia.home.stateVersion = "$RELEASE";
}
EOF

cat > "$HOST_DIR/${HOSTNAME}_packages.nix" << EOF
{
  config,
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
  ];
}
EOF

cat > "$HOST_DIR/${HOSTNAME}_programs.nix" << EOF
{ ... }:

{
  programs = {
  };
}
EOF

cat > "$HOST_DIR/${HOSTNAME}_services.nix" << EOF
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
