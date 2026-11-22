#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIN="$REPO_ROOT/diy-packages/pangolin-cli.json"
REPO="fosrl/cli"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

usage() {
  cat >&2 <<EOF
Usage: $0 [version]

Moves the pangolin-cli pin in diy-packages/pangolin-cli.json to the latest
release of $REPO, or to the version given: the version, the hash of the source
and the hash of the Go dependencies, which is read off a build that is made to
fail on purpose.
EOF
  exit 1
}

[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && usage

json_field() {
  grep -oP "\"$1\"\\s*:\\s*\"\\K[^\"]+" | head -1
}

nix_cmd() {
  nix --extra-experimental-features "nix-command flakes" "$@"
}

write_pin() {
  printf '{\n  "version": "%s",\n  "hash": "%s",\n  "vendorHash": "%s"\n}\n' "$1" "$2" "$3" >"$PIN"
}

current="$(json_field version <"$PIN")"
current_hash="$(json_field hash <"$PIN")"
current_vendor="$(json_field vendorHash <"$PIN")"

latest="${1:-}"
if [ -z "$latest" ]; then
  auth=()
  [ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ] && auth=(-H "Authorization: Bearer ${GH_TOKEN:-$GITHUB_TOKEN}")
  if ! release="$(curl -fsSL "${auth[@]}" "https://api.github.com/repos/$REPO/releases/latest")"; then
    echo "pangolin-cli: could not reach the GitHub API" >&2
    exit 1
  fi
  latest="$(printf '%s' "$release" | json_field tag_name)"
fi

if [[ ! "$latest" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "pangolin-cli: '$latest' does not look like a release version" >&2
  exit 1
fi

if [ "$latest" = "$current" ]; then
  echo "pangolin-cli: up to date ($current)"
  exit 0
fi

restore() {
  write_pin "$current" "$current_hash" "$current_vendor"
}
trap restore ERR
trap 'restore; exit 130' INT TERM

prefetch="$(nix_cmd store prefetch-file --unpack --json "https://github.com/$REPO/archive/refs/tags/$latest.tar.gz")"
hash="$(printf '%s' "$prefetch" | json_field hash)"
if [[ ! "$hash" =~ ^sha256-[A-Za-z0-9+/]+=*$ ]]; then
  echo "pangolin-cli: bad source hash from prefetch ('$hash')" >&2
  restore
  exit 1
fi

write_pin "$latest" "$hash" "$FAKE_HASH"
host="$(nix_cmd eval --raw --no-write-lock-file "$REPO_ROOT#nixosConfigurations" --apply 'ns: builtins.head (builtins.attrNames ns)')"
log="$(nix_cmd build --no-link --no-write-lock-file "$REPO_ROOT#nixosConfigurations.$host.pkgs.pangolin-cli.goModules" 2>&1 || true)"
vendor="$(printf '%s\n' "$log" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/]+=*' | head -1 || true)"
if [ -z "$vendor" ]; then
  echo "pangolin-cli: no dependency hash in the build output" >&2
  printf '%s\n' "$log" | tail -20 >&2
  restore
  exit 1
fi

write_pin "$latest" "$hash" "$vendor"
trap - ERR INT TERM
echo "pangolin-cli: $current -> $latest"
