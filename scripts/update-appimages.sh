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

# update_pkg <name> <owner/repo> <nix file> <asset template> [tag prefix]
# In the template {tag} is the release tag and {version} the tag without its
# prefix. With a prefix, the newest release whose tag starts with it is taken:
# for a repository that releases several things side by side.
update_pkg() {
  local name="$1" repo="$2" nix_file="$3" asset_tpl="$4" prefix="${5:-}"

  local release_json latest_tag endpoint="releases/latest"
  [ -n "$prefix" ] && endpoint="releases?per_page=100"
  local -a auth=()
  [ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ] && auth=(-H "Authorization: Bearer ${GH_TOKEN:-$GITHUB_TOKEN}")
  if ! release_json=$(curl -fsSL "${auth[@]}" "https://api.github.com/repos/${repo}/${endpoint}"); then
    echo "$name: could not reach the GitHub API" >&2
    return 1
  fi
  latest_tag=$(printf '%s' "$release_json" | grep -oP "\"tag_name\"\\s*:\\s*\"\\K${prefix}[^\"]+" | head -1 || true)

  if [ -z "$latest_tag" ]; then
    echo "$name: no release tag found" >&2
    return 1
  fi
  local latest_version="${latest_tag#"$prefix"}"

  local current_version current_hash
  current_version=$(grep -oP 'version = "\K[^"]+' "$nix_file" | head -1)
  current_hash=$(grep -oP 'sha256 = "\K[^"]+' "$nix_file" | head -1)

  local asset="${asset_tpl//\{tag\}/$latest_tag}"
  asset="${asset//\{version\}/$latest_version}"
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

  if [ "$latest_version" = "$current_version" ] && [ "$sri_hash" = "$current_hash" ] && [ "$FORCE" -eq 0 ]; then
    echo "$name: up to date ($current_version)"
    return 0
  fi

  echo "$name: $current_version -> $latest_version"
  [ "$sri_hash" = "$current_hash" ] || echo "$name: hash $current_hash -> $sri_hash"

  sed -i \
    -e "0,/version = \"[^\"]*\"/s|version = \"[^\"]*\"|version = \"${latest_version}\"|" \
    -e "0,/sha256 = \"[^\"]*\"/s|sha256 = \"[^\"]*\"|sha256 = \"${sri_hash}\"|" \
    "$nix_file"

  if ! grep -qF "version = \"${latest_version}\"" "$nix_file"; then
    echo "$name: version was not written to $nix_file" >&2
    return 1
  fi
  if ! grep -qF "sha256 = \"${sri_hash}\"" "$nix_file"; then
    echo "$name: hash was not written to $nix_file" >&2
    return 1
  fi

  echo "$name: updated to $latest_version"
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

update_pangolin_client() {
  update_pkg "pangolin-client" "fosrl/windows-linux" \
    "$REPO_ROOT/diy-packages/pangolin-client.nix" \
    "pangolin-client-amd64-{version}.tar.gz" \
    "linux-"
}

usage() {
  echo "Usage: $0 [-f|--force] [zen|helium|pangolin-client|all]"
  echo "  -f, --force   Rewrite version and hash even when they already match"
}

target="all"
for arg in "$@"; do
  case "$arg" in
    -f|--force) FORCE=1 ;;
    zen|helium|pangolin-client|all) target="$arg" ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
  esac
done

rc=0
case "$target" in
  zen)    update_zen || rc=1 ;;
  helium) update_helium || rc=1 ;;
  pangolin-client) update_pangolin_client || rc=1 ;;
  all)    update_zen || rc=1; update_helium || rc=1; update_pangolin_client || rc=1 ;;
esac

exit "$rc"
