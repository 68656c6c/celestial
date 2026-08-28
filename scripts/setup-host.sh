#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="${1:?Usage: $0 <hostname>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_DIR="$REPO_ROOT/system/per_host/$HOSTNAME"
HOSTS_FILE="$REPO_ROOT/system/hosts.nix"
SOPS_FILE="$REPO_ROOT/.sops.yaml"

if [ -d "$HOST_DIR" ]; then
  echo "Error: $HOST_DIR already exists" >&2
  exit 1
fi

echo "==> Generating hardware config..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
sudo nixos-generate-config --dir "$TMP_DIR"
mkdir -p "$HOST_DIR"
mv "$TMP_DIR/hardware-configuration.nix" "$HOST_DIR/hardware-configuration.$HOSTNAME.nix"
sudo chown "$(id -u):$(id -g)" "$HOST_DIR/hardware-configuration.$HOSTNAME.nix"

echo "==> Generating sops age key..."
sudo mkdir -p /etc/sops-age
sudo age-keygen -o /etc/sops-age/keys 2>/dev/null
sudo chmod 600 /etc/sops-age/keys
PUBKEY=$(sudo age-keygen -y /etc/sops-age/keys)

echo "==> Adding $HOSTNAME to system/hosts.nix..."
sed -i "s/^}$/  $HOSTNAME = { };\n}/" "$HOSTS_FILE"
sed -i "/^- &backup /i\\  - &host_$HOSTNAME $PUBKEY" "$SOPS_FILE"
sed -i "/^  all: &all$/i\\  $HOSTNAME: &$HOSTNAME\n    - *host_$HOSTNAME\n    - *backup" "$SOPS_FILE"
sed -i "s/    - \*backup$/    - *host_$HOSTNAME\n    - *backup/" "$SOPS_FILE"

cat >> "$SOPS_FILE" << EOF
  - path_regex: secrets/vpn_$HOSTNAME\.ovpn$
    key_groups:
      - age: *$HOSTNAME
EOF

cat > "$HOST_DIR/default.nix" << EOF
{ ... }:

{
  imports = [
    ./$HOSTNAME\_packages.nix
    ./$HOSTNAME\_configurations.nix
    ./$HOSTNAME\_programs.nix
    ./$HOSTNAME\_services.nix
  ];
}
EOF

cat > "$HOST_DIR/$HOSTNAME\_configurations.nix" << EOF
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

  vpn.lab_local = {
    enable = true;
    updateDns = true;
  };

  vpn.tailscale.enable = true;
}
EOF

cat > "$HOST_DIR/$HOSTNAME\_packages.nix" << EOF
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

cat > "$HOST_DIR/$HOSTNAME\_programs.nix" << EOF
{ ... }:

{
  programs = {
  };
}
EOF

cat > "$HOST_DIR/$HOSTNAME\_services.nix" << EOF
{ ... }:

{
  services = {
  };
}
EOF

echo "public key: $PUBKEY"
echo "1. dns, monitor and vpn settings in $HOST_DIR/$HOSTNAME\_configurations.nix"
echo "2. re-encrypt secrets with: sops updatekeys secrets/"
