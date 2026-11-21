#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_NAME="${ATTIC_CACHE:-celestial}"
CACHE_URL="${ATTIC_CACHE_URL:-https://attic.artesia.cloud/$CACHE_NAME}"
DO_PUSH="${PUSH:-1}"
CACHIX_NAME="${CACHIX_CACHE:-celestial}"
SLOW_PACKAGES="${SLOW_PACKAGES:-nlohmann_json millennium stremio lzbt-systemd}"
SLOW_ONLY="${SLOW_ONLY:-0}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

if [ -z "${ATTIC_TOKEN:-}" ] && [ -r "$CONFIG_HOME/attic/config.toml" ]; then
  ATTIC_TOKEN="$(sed -n 's/^token *= *"\(.*\)"$/\1/p' "$CONFIG_HOME/attic/config.toml" | head -n 1)"
fi

HAVE_CACHIX=0
if [ -n "${CACHIX_AUTH_TOKEN:-}" ] || [ -s "$CONFIG_HOME/cachix/cachix.dhall" ]; then
  HAVE_CACHIX=1
fi

usage() {
  cat >&2 <<EOF
Usage: $0 [host...]

Builds each host's system closure and pushes it to the attic cache, skipping
hosts whose toplevel is already present. With no arguments, does every host.

The slow packages of a host are built and pushed on their own first, to every
cache that lacks them, so they are kept even when the rest of the host fails.

Environment:
  ATTIC_TOKEN      token for the private cache (narinfo checks; attic push uses its login),
                   default: the first one in ~/.config/attic/config.toml
  CACHIX_AUTH_TOKEN  when set, or after \`cachix authtoken\`, what was built also goes
                   to the public cachix cache
  SLOW_ONLY        set to 1 to stop after the slow packages (default: 0)
  CACHIX_CACHE     cachix cache name           (default: celestial)
  ATTIC_CACHE      cache name for attic push   (default: celestial)
  ATTIC_CACHE_URL  binary cache endpoint       (default: https://attic.artesia.cloud/\$ATTIC_CACHE)
  PUSH             set to 0 to build only      (default: 1)
  SLOW_PACKAGES    package names pushed first  (default: $SLOW_PACKAGES)
EOF
  exit 1
}

[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && usage

has_narinfo() {
  local url="$1" hash="${2#/nix/store/}"
  shift 2
  hash="${hash%%-*}"
  [ "$(curl -sS -o /dev/null -w '%{http_code}' "$@" "$url/$hash.narinfo")" = "200" ]
}

in_cache() {
  local -a auth=()
  [ -n "${ATTIC_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $ATTIC_TOKEN")
  has_narinfo "$CACHE_URL" "$1" "${auth[@]}"
}

push_cachix() {
  nix run --inputs-from "$REPO_ROOT" nixpkgs#cachix -- push "$CACHIX_NAME" "$@" \
    || echo "    cachix push failed, carrying on" >&2
}

push_slow() {
  local host="$1" attr="$2" pattern top drv name out need_attic need_cachix
  local -a drvs outs
  pattern="^/nix/store/[a-z0-9]+-(${SLOW_PACKAGES// /|})"
  if ! top="$(nix path-info --derivation --no-write-lock-file "$attr")"; then
    echo "    $host: evaluation failed, slow packages left out" >&2
    return 0
  fi
  mapfile -t drvs < <(nix-store -qR "$top" | grep -E "$pattern" || true)
  for drv in "${drvs[@]}"; do
    mapfile -t outs < <(nix-store -q --outputs "$drv")
    need_attic=0
    need_cachix=0
    for out in "${outs[@]}"; do
      has_narinfo https://cache.nixos.org "$out" && continue
      in_cache "$out" || need_attic=1
      if [ "$HAVE_CACHIX" = 1 ] && ! has_narinfo "https://$CACHIX_NAME.cachix.org" "$out"; then
        need_cachix=1
      fi
    done
    [ "$need_attic" = 0 ] && [ "$need_cachix" = 0 ] && continue

    name="${drv#/nix/store/*-}"
    echo "==> $host: ${name%.drv} first"
    if ! nix build --no-link --print-build-logs "$drv^*"; then
      echo "    build failed, left to the host build" >&2
      continue
    fi
    if [ "$need_attic" = 1 ]; then
      attic push "$CACHE_NAME" "${outs[@]}" || echo "    attic push failed, carrying on" >&2
    fi
    if [ "$need_cachix" = 1 ]; then
      push_cachix "${outs[@]}"
    fi
  done
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

  if [ "$SLOW_ONLY" = 1 ]; then
    echo "==> $host: slow packages"
    push_slow "$host" "$attr"
    continue
  fi

  echo "==> $host: evaluating"
  if ! out="$(nix eval --raw --no-write-lock-file "$attr.outPath")"; then
    echo "    evaluation failed" >&2
    failed+=("$host")
    continue
  fi
  echo "    $out"

  if [ "$DO_PUSH" = 1 ]; then
    push_slow "$host" "$attr"
  fi

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
