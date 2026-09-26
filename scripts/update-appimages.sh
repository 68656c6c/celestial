#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

update_zen() {
  echo "Checking zen-browser latest release..."
  local latest_tag
  latest_tag=$(curl -s "https://api.github.com/repos/zen-browser/desktop/releases/latest" | grep -oP '"tag_name":\s*"\K[^"]+' | head -1)

  if [ -z "$latest_tag" ]; then
    echo "Failed to fetch zen-browser latest release"
    return 1
  fi

  local current_version
  current_version=$(grep -oP 'version = "\K[^"]+' "$REPO_ROOT/diy-packages/zen-browser.nix")

  if [ "$latest_tag" = "$current_version" ]; then
    echo "zen-browser already up to date ($current_version)"
    return 0
  fi

  echo "Updating zen-browser from $current_version to $latest_tag"

  local download_url="https://github.com/zen-browser/desktop/releases/download/${latest_tag}/zen-x86_64.AppImage"
  echo "Fetching hash for: $download_url"

  local new_hash
  new_hash=$(nurl "$download_url" 2>&1 | grep -oP 'sha256-\K[A-Za-z0-9+/=]+' | head -1)

  if [ -z "$new_hash" ]; then
    echo "Failed to compute hash"
    return 1
  fi

  sed -i "s/version = \"[^\"]*\"/version = \"$latest_tag\"/" "$REPO_ROOT/diy-packages/zen-browser.nix"
  sed -i "s/sha256 = \"sha256-[^\"]*\"/sha256 = \"sha256-$new_hash\"/" "$REPO_ROOT/diy-packages/zen-browser.nix"

  echo "Updated zen-browser to $latest_tag"
}

update_helium() {
  echo "Checking helium latest release..."
  local latest_tag
  latest_tag=$(curl -s "https://api.github.com/repos/imputnet/helium-linux/releases/latest" | grep -oP '"tag_name":\s*"\K[^"]+' | head -1)

  if [ -z "$latest_tag" ]; then
    echo "Failed to fetch helium latest release"
    return 1
  fi

  local current_version
  current_version=$(grep -oP 'version = "\K[^"]+' "$REPO_ROOT/diy-packages/helium.nix")

  if [ "$latest_tag" = "$current_version" ]; then
    echo "helium already up to date ($current_version)"
    return 0
  fi

  echo "Updating helium from $current_version to $latest_tag"

  local download_url="https://github.com/imputnet/helium-linux/releases/download/${latest_tag}/helium-${latest_tag}-x86_64.AppImage"
  echo "Fetching hash for: $download_url"

  local new_hash
  new_hash=$(nurl "$download_url" 2>&1 | grep -oP 'sha256-\K[A-Za-z0-9+/=]+' | head -1)

  if [ -z "$new_hash" ]; then
    echo "Failed to compute hash"
    return 1
  fi

  sed -i "s/version = \"[^\"]*\"/version = \"$latest_tag\"/" "$REPO_ROOT/diy-packages/helium.nix"
  sed -i "s/sha256 = \"sha256-[^\"]*\"/sha256 = \"sha256-$new_hash\"/" "$REPO_ROOT/diy-packages/helium.nix"

  echo "Updated helium to $latest_tag"
}

case "${1:-all}" in
  zen)
    update_zen
    ;;
  helium)
    update_helium
    ;;
  all)
    update_zen
    update_helium
    ;;
  *)
    echo "Usage: $0 [zen|helium|all]"
    exit 1
    ;;
esac

echo "Done."
