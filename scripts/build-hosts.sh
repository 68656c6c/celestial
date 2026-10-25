#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_NAME="${ATTIC_CACHE:-celestial}"
CACHE_URL="${ATTIC_CACHE_URL:-https://attic.artesia.cloud/$CACHE_NAME}"
DO_PUSH="${PUSH:-1}"

usage() {
  cat >&2 <<EOF
Usage: $0 [host...]

Builds each host's system closure and pushes it to the attic cache, skipping
hosts whose toplevel is already present. With no arguments, does every host.

Environment:
  ATTIC_TOKEN      token for the private cache (narinfo checks; attic push uses its login)
  ATTIC_CACHE      cache name for attic push   (default: celestial)
  ATTIC_CACHE_URL  binary cache endpoint       (default: https://attic.artesia.cloud/\$ATTIC_CACHE)
  PUSH             set to 0 to build only      (default: 1)
EOF
  exit 1
}

[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && usage

in_cache() {
  local hash="${1#/nix/store/}"
  hash="${hash%%-*}"
  local -a auth=()
  [ -n "${ATTIC_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $ATTIC_TOKEN")
  [ "$(curl -sS -o /dev/null -w '%{http_code}' "${auth[@]}" "$CACHE_URL/$hash.narinfo")" = "200" ]
}

hosts=("$@")
if [ "${#hosts[@]}" -eq 0 ]; then
  all_hosts="$(
    nix eval --raw "$REPO_ROOT#nixosConfigurations" \
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
  if ! out="$(nix eval --raw "$attr.outPath")"; then
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
  if ! nix build --no-link --print-build-logs "$attr"; then
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
  fi

  built+=("$host")
done

echo
echo "==> summary"
[ "${#built[@]}" -gt 0 ] && echo "    built:   ${built[*]}"
[ "${#skipped[@]}" -gt 0 ] && echo "    skipped: ${skipped[*]}"
[ "${#failed[@]}" -gt 0 ] && echo "    failed:  ${failed[*]}"

[ "${#failed[@]}" -eq 0 ]
