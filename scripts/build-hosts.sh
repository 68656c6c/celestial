#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_NAME="${ATTIC_CACHE:-celestial}"
CACHE_URL="${ATTIC_CACHE_URL:-https://attic.cl2.artesia.cloud/$CACHE_NAME}"
DO_PUSH="${PUSH:-1}"
CACHIX_NAME="${CACHIX_CACHE:-celestial}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

HAVE_CACHIX=0
if [ -n "${CACHIX_AUTH_TOKEN:-}" ] || [ -s "$CONFIG_HOME/cachix/cachix.dhall" ]; then
  HAVE_CACHIX=1
fi

usage() {
  cat >&2 <<EOF
Usage: $0 [host...]

Builds each host's system closure and pushes it to the attic cache, skipping
hosts whose toplevel is already present. With no arguments, does every host.

Environment:
  CACHIX_AUTH_TOKEN  when set, or after \`cachix authtoken\`, what was built also goes
                   to the public cachix cache
  CACHIX_CACHE     cachix cache name           (default: celestial)
  ATTIC_CACHE      cache name for attic push   (default: celestial)
  ATTIC_CACHE_URL  binary cache endpoint       (default: https://attic.cl2.artesia.cloud/\$ATTIC_CACHE)
  PUSH             set to 0 to build only      (default: 1)
EOF
  exit 1
}

[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && usage

has_narinfo() {
  local url="$1" hash="${2#/nix/store/}"
  hash="${hash%%-*}"
  [ "$(curl -sS -o /dev/null -w '%{http_code}' "$url/$hash.narinfo")" = "200" ]
}

in_cache() {
  has_narinfo "$CACHE_URL" "$1"
}

push_cachix() {
  nix run --inputs-from "$REPO_ROOT" nixpkgs#cachix -- push "$CACHIX_NAME" "$@" \
    || echo "    cachix push failed, carrying on" >&2
}

hosts=("$@")
if [ "${#hosts[@]}" -eq 0 ]; then
  all_hosts="$(
    nix eval --raw --no-write-lock-file "$REPO_ROOT#nixosConfigurations" \
      --apply 'ns: builtins.concatStringsSep " " (builtins.attrNames ns)'
  )"
  read -r -a hosts <<<"$all_hosts"
fi

built=()
skipped=()
failed=()

for host in "${hosts[@]}"; do
  attr="$REPO_ROOT#nixosConfigurations.$host.config.system.build.toplevel"

  echo "==> $host: evaluating"
  if ! out="$(nix eval --raw --no-write-lock-file "$attr.outPath")"; then
    echo "    evaluation failed" >&2
    failed+=("$host")
    continue
  fi
  echo "    $out"

  if in_cache "$out"; then
    echo "    already in $CACHE_NAME, nothing to do"
    skipped+=("$host")
    continue
  fi

  echo "==> $host: building"
  if ! nix build --no-link --print-build-logs --no-write-lock-file "$attr"; then
    echo "    build failed" >&2
    failed+=("$host")
    continue
  fi

  if [ "$DO_PUSH" = 1 ]; then
    echo "==> $host: pushing"
    if ! attic push "$CACHE_NAME" "$out"; then
      echo "    push failed" >&2
      failed+=("$host")
      continue
    fi
    # Second copy on cachix: reachable without the lab network or a token, so
    # an install or a switch away from home does not compile. cachix leaves
    # out what cache.nixos.org already has. Not fatal, attic is the real one.
    if [ "$HAVE_CACHIX" = 1 ]; then
      echo "==> $host: pushing to cachix"
      push_cachix "$out"
    fi
  fi

  built+=("$host")
done

echo
echo "==> summary"
[ "${#built[@]}" -gt 0 ] && echo "    built:   ${built[*]}"
[ "${#skipped[@]}" -gt 0 ] && echo "    skipped: ${skipped[*]}"
[ "${#failed[@]}" -gt 0 ] && echo "    failed:  ${failed[*]}"

[ "${#failed[@]}" -eq 0 ]
