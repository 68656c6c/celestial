#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="${1:?Usage: $0 <hostname>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="$REPO_ROOT/system/per_host/$HOSTNAME"
TARGET_FILE="$TARGET_DIR/hardware-configuration.$HOSTNAME.nix"

if [ -f "$TARGET_FILE" ]; then
  echo "Error: $TARGET_FILE already exists" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

sudo nixos-generate-config --dir "$TMP_DIR"

mkdir -p "$TARGET_DIR"
mv "$TMP_DIR/hardware-configuration.nix" "$TARGET_FILE"
sudo chown "$(id -u):$(id -g)" "$TARGET_FILE"

echo "Wrote $TARGET_FILE, If this is a new host, add a new entry in flake.nix"