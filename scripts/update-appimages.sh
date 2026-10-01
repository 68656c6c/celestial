#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORCE=0

json_field() {
  grep -oP "\"$1\"\\s*:\\s*\"\\K[^\"]+" | head -1
}

nix_cmd() {
  nix --extra-experimental-features "nix-command flakes" "$@"
}

# update_pkg <name> <owner/repo> <nix file> <asset template, {tag} = release tag>
update_pkg() {
  local name="$1" repo="$2" nix_file="$3" asset_tpl="$4"

  local release_json latest_tag
  if ! release_json=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest"); then
    echo "$name: could not reach the GitHub API" >&2
    return 1
  fi
  latest_tag=$(printf '%s' "$release_json" | json_field tag_name)

  if [ -z "$latest_tag" ]; then
    echo "$name: no tag_name in the latest release" >&2
    return 1
  fi

  local current_version current_hash
  current_version=$(grep -oP 'version = "\K[^"]+' "$nix_file" | head -1)
  current_hash=$(grep -oP 'sha256 = "\K[^"]+' "$nix_file" | head -1)

  local asset="${asset_tpl//\{tag\}/$latest_tag}"
  local download_url="https://github.com/${repo}/releases/download/${latest_tag}/${asset}"

  local prefetch sri_hash
  if ! prefetch=$(nix_cmd store prefetch-file --json "$download_url"); then
    echo "$name: could not fetch $download_url" >&2
    return 1
  fi
  sri_hash=$(printf '%s' "$prefetch" | json_field hash)

  if [[ ! "$sri_hash" =~ ^sha256-[A-Za-z0-9+/]+=*$ ]]; then
    echo "$name: bad hash from prefetch ('${sri_hash}')" >&2
    return 1
  fi

  if [ "$latest_tag" = "$current_version" ] && [ "$sri_hash" = "$current_hash" ] && [ "$FORCE" -eq 0 ]; then
    echo "$name: up to date ($current_version)"
    return 0
  fi

  echo "$name: $current_version -> $latest_tag"
  [ "$sri_hash" = "$current_hash" ] || echo "$name: hash $current_hash -> $sri_hash"

  sed -i \
    -e "0,/version = \"[^\"]*\"/s|version = \"[^\"]*\"|version = \"${latest_tag}\"|" \
    -e "0,/sha256 = \"[^\"]*\"/s|sha256 = \"[^\"]*\"|sha256 = \"${sri_hash}\"|" \
    "$nix_file"

  if ! grep -qF "version = \"${latest_tag}\"" "$nix_file"; then
    echo "$name: version was not written to $nix_file" >&2
    return 1
  fi
  if ! grep -qF "sha256 = \"${sri_hash}\"" "$nix_file"; then
    echo "$name: hash was not written to $nix_file" >&2
    return 1
  fi

  echo "$name: updated to $latest_tag"
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
  echo "  -f, --force   Rewrite version and hash even when they already match"
}

target="all"
for arg in "$@"; do
  case "$arg" in
    -f|--force) FORCE=1 ;;
    zen|helium|all) target="$arg" ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done

rc=0
case "$target" in
  zen)    update_zen || rc=1 ;;
  helium) update_helium || rc=1 ;;
  all)    update_zen || rc=1; update_helium || rc=1 ;;
esac

exit "$rc"
