#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="${1:?Usage: $0 <hostname>}"
KEY_DIR="/etc/sops-age"
KEY_FILE="$KEY_DIR/keys"

if [ -f "$KEY_FILE" ]; then
  echo "Error: $KEY_FILE already exists" >&2
  echo "Remove it first if you want to generate a new key" >&2
  exit 1
fi

sudo mkdir -p "$KEY_DIR"
sudo age-keygen -o "$KEY_FILE"
sudo chmod 600 "$KEY_FILE"

PUBKEY=$(sudo age-keygen -y "$KEY_FILE")
echo ""
echo "Public key for $HOSTNAME: $PUBKEY"
echo ""
echo "Add this to .sops.yaml under keys:"
echo "  - &$HOSTNAME $PUBKEY"
