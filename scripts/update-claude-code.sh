#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIN="$REPO_ROOT/diy-packages/claude-code.json"
BASE_URL="https://downloads.claude.ai/claude-code-releases"

usage() {
  cat >&2 <<EOF2
Usage: $0 [version]

Moves the Claude Code pin in diy-packages/claude-code.json to the latest
release, or to the version given. The pin is the release's own manifest, the
one nixpkgs' claude-code package reads: version, and per platform the binary
and its checksum.
EOF2
  exit 1
}

[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && usage

json_field() {
  grep -oP "\"$1\"\\s*:\\s*\"\\K[^\"]+" | head -1
}

current="$(json_field version <"$PIN")"

latest="${1:-}"
if [ -z "$latest" ] && ! latest="$(curl -fsSL --retry 3 "$BASE_URL/latest")"; then
  echo "claude-code: could not reach $BASE_URL" >&2
  exit 1
fi

if [[ ! "$latest" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "claude-code: '$latest' does not look like a release version" >&2
  exit 1
fi

if [ "$latest" = "$current" ]; then
  echo "claude-code: up to date ($current)"
  exit 0
fi

manifest="$(mktemp)"
trap 'rm -f "$manifest"' EXIT
curl -fsSL --retry 3 "$BASE_URL/$latest/manifest.zst.json" -o "$manifest"

# the package reads these: a manifest without them would only fail at build time
if [ "$(json_field version <"$manifest")" != "$latest" ] \
  || ! grep -qP '"linux-x64"\s*:' "$manifest" \
  || ! grep -qP '"checksum"\s*:\s*"[0-9a-f]{64}"' "$manifest"; then
  echo "claude-code: the manifest for $latest is not what the package expects" >&2
  exit 1
fi

cp "$manifest" "$PIN"
echo "claude-code: $current -> $latest"
