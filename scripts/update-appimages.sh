#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORCE=0

# Usage: update_pkg <name> <github owner/repo> <nix file> <asset filename template>
#   The template may contain {tag}, which is replaced with the release tag.
update_pkg() {
  local name="$1" repo="$2" nix_file="$3" asset_tpl="$4"

  echo "Checking $name latest release..."
  local latest_tag
  latest_tag=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name // empty')

  if [ -z "$latest_tag" ]; then
    echo "Failed to fetch $name latest release"
    return 1
  fi

  local current_version
  current_version=$(grep -oP 'version = "\K[^"]+' "$nix_file" | head -1)

  if [ "$latest_tag" = "$current_version" ] && [ "$FORCE" -eq 0 ]; then
    echo "$name already up to date ($current_version)"
    return 0
  fi

  echo "Updating $name from $current_version to $latest_tag"

  local asset="${asset_tpl//\{tag\}/$latest_tag}"
  local download_url="https://github.com/${repo}/releases/download/${latest_tag}/${asset}"
  echo "Fetching hash for: $download_url"

  # Download the actual file and get its SRI hash (sha256-...)
  local sri_hash
  sri_hash=$(nix --extra-experimental-features nix-command \
    store prefetch-file --json "$download_url" | jq -r '.hash // empty')

  if [[ ! "$sri_hash" =~ ^sha256-[A-Za-z0-9+/]+=*$ ]]; then
    echo "Failed to compute hash (got: '${sri_hash}')"
    return 1
  fi

  sed -i "s|sha256 = \"sha256-[^\"]*\"|sha256 = \"${sri_hash}\"|" "$nix_file"
  sed -i "0,/version = \"[^\"]*\"/s||version = \"${latest_tag}\"|" "$nix_file"

  if ! grep -qF "sha256 = \"${sri_hash}\"" "$nix_file"; then
    echo "Hash was not written to $nix_file (does it use 'sha256 = \"sha256-...\"'?)"
    return 1
  fi
  if ! grep -qF "version = \"${latest_tag}\"" "$nix_file"; then
    echo "Version was not written to $nix_file"
    return 1
  fi

  echo "Updated $name to $latest_tag"
}

update_zen() {
  update_pkg "zen-browser" "zen-browser/desktop" \
    "$REPO_ROOT/diy-packages/zen-browser.nix" \
    "zen-x86_64.AppImage"
}

update_helium() {
  update_pkg "helium" "imputnet/helium-linux" \
    "$REPO_ROOT/diy-packages/helium.nix" \
    "helium-{tag}-x86_64.AppImage"
}

usage() {
  echo "Usage: $0 [-f|--force] [zen|helium|all]"
  echo "  -f, --force   Re-fetch the hash"
}

target="all"
for arg in "$@"; do
  case "$arg" in
    -f|--force) FORCE=1 ;;
    zen|helium|all) target="$arg" ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

case "$target" in
  zen)    update_zen ;;
  helium) update_helium ;;
  all)    update_zen; update_helium ;;
esac

echo "Done."