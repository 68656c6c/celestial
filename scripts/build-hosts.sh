#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_NAME="${ATTIC_CACHE:-celestial}"
CACHE_URL="${ATTIC_CACHE_URL:-https://attic.cl2.artesia.cloud/$CACHE_NAME}"
DO_PUSH="${PUSH:-1}"
CACHIX_NAME="${CACHIX_CACHE:-celestial}"
CACHIX_URL="https://$CACHIX_NAME.cachix.org"
# cachix is 5 GB: only what takes long to build goes there, not whole hosts
CACHIX_PACKAGES="${CACHIX_PACKAGES:-nlohmann_json millennium stremio lzbt-systemd}"
HAVE_ATTIC="${ATTIC_UP:-true}"
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
  CACHIX_AUTH_TOKEN  when set, or after \`cachix authtoken\`, the packages named in
                   CACHIX_PACKAGES also go to the public cachix cache
  CACHIX_PACKAGES  package names for cachix    (default: $CACHIX_PACKAGES)
  CACHIX_CACHE     cachix cache name           (default: celestial)
  ATTIC_CACHE      cache name for attic push   (default: celestial)
  ATTIC_CACHE_URL  binary cache endpoint       (default: https://attic.cl2.artesia.cloud/\$ATTIC_CACHE)
  ATTIC_UP         set to false when attic is out of reach: hosts are still built,
                   their CACHIX_PACKAGES go to cachix, and the run fails at the end (default: true)
  PUSH             set to 0 to build only      (default: 1)
EOF
  exit 1
}

[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && usage

warn() {
  if [ "${GITHUB_ACTIONS:-}" = true ]; then
    echo "::warning::$*"
  else
    echo "    $*" >&2
  fi
}

has_narinfo() {
  local url="$1" hash="${2#/nix/store/}"
  hash="${hash%%-*}"
  local code
  code="$(
    curl -sS --retry 3 --retry-all-errors --connect-timeout 10 -m 30 \
      -o /dev/null -w '%{http_code}' "$url/$hash.narinfo"
  )" || return 1
  [ "$code" = "200" ]
}

in_cache() {
  [ "$HAVE_ATTIC" = true ] && has_narinfo "$CACHE_URL" "$1"
}

# The toplevel goes last and alone. Its narinfo is what in_cache reads, and
# attic uploads a closure in no particular order: pushed in one go, a push
# that dies halfway can leave the toplevel there without what it refers to.
push_attic() {
  local out="$1"
  nix-store -qR "$out" | grep -vxF -- "$out" | attic push --stdin --no-closure "$CACHE_NAME" \
    && attic push --no-closure "$CACHE_NAME" "$out"
}

# The named packages in a host's closure that cachix lacks. cachix leaves out
# what cache.nixos.org has, so their dependencies cost nothing there.
push_cachix() {
  local out="$1" path
  local -a missing=()
  while IFS= read -r path; do
    has_narinfo "$CACHIX_URL" "$path" || missing+=("$path")
  done < <(nix-store -qR "$out" | grep -E "^/nix/store/[a-z0-9]+-(${CACHIX_PACKAGES// /|})" || true)
  [ "${#missing[@]}" -gt 0 ] || return 0
  printf '    %s\n' "${missing[@]}"
  nix run --inputs-from "$REPO_ROOT" nixpkgs#cachix -- push "$CACHIX_NAME" "${missing[@]}"
}

hosts=("$@")
if [ "${#hosts[@]}" -eq 0 ]; then
  all_hosts="$(
    nix eval --raw --no-write-lock-file "$REPO_ROOT#nixosConfigurations" \
      --apply 'ns: builtins.concatStringsSep " " (builtins.attrNames ns)'
  )"
  read -r -a hosts <<<"$all_hosts"
fi

# One line per phase in the log and on the run page: where the time goes
phase() {
  echo "    $2 took ${SECONDS}s"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    echo "| $1 | $2 | $SECONDS |" >>"$GITHUB_STEP_SUMMARY"
  fi
  SECONDS=0
}
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  printf '| host | phase | seconds |\n| --- | --- | --- |\n' >>"$GITHUB_STEP_SUMMARY"
fi

if [ "$DO_PUSH" = 1 ] && [ "$HAVE_ATTIC" != true ] && [ "$HAVE_CACHIX" = 0 ]; then
  echo "attic is out of reach and there is no cachix token: nowhere to push, nothing built" >&2
  exit 1
fi
if [ "$DO_PUSH" = 1 ] && [ "$HAVE_CACHIX" = 0 ]; then
  warn "no cachix token, nothing goes to $CACHIX_URL"
fi

built=()
skipped=()
failed=()
not_on_attic=()
not_on_cachix=()

for host in "${hosts[@]}"; do
  attr="$REPO_ROOT#nixosConfigurations.$host.config.system.build.toplevel"

  echo "==> $host: evaluating"
  SECONDS=0
  # shellcheck disable=SC2016  # a Nix expression, not a shell one
  if ! paths="$(nix eval --raw --no-write-lock-file "$attr" --apply 'd: "${d.drvPath} ${d.outPath}"')"; then
    echo "    evaluation failed" >&2
    failed+=("$host")
    continue
  fi
  drv="${paths%% *}"
  out="${paths##* }"
  echo "    $out"
  phase "$host" evaluate

  if in_cache "$out"; then
    echo "    already in $CACHE_NAME, nothing to do"
    skipped+=("$host")
    continue
  fi

  echo "==> $host: building"
  # by derivation: the flake is not evaluated a second time
  if ! nix build --no-link --print-build-logs "$drv^*"; then
    echo "    build failed" >&2
    phase "$host" "build (failed)"
    failed+=("$host")
    continue
  fi
  phase "$host" build

  if [ "$DO_PUSH" = 1 ]; then
    attic_ok=1
    if [ "$HAVE_ATTIC" = true ]; then
      echo "==> $host: pushing"
      if ! push_attic "$out"; then
        echo "    push failed" >&2
        attic_ok=0
      fi
      phase "$host" "attic push"
    else
      attic_ok=0
    fi
    # The slow builds also go to cachix, which answers without the lab
    # network. Not fatal, attic is the real one.
    if [ "$HAVE_CACHIX" = 1 ]; then
      echo "==> $host: slow packages to cachix"
      if ! push_cachix "$out"; then
        not_on_cachix+=("$host")
      fi
      phase "$host" "cachix push"
    fi
    if [ "$attic_ok" = 0 ]; then
      not_on_attic+=("$host")
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
[ "${#not_on_attic[@]}" -gt 0 ] && echo "    not on attic: ${not_on_attic[*]}"
[ "${#not_on_cachix[@]}" -gt 0 ] && warn "not on cachix: ${not_on_cachix[*]}"

[ "${#failed[@]}" -eq 0 ] && { [ "$DO_PUSH" != 1 ] || [ "${#not_on_attic[@]}" -eq 0 ]; }
