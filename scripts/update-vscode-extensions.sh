#!/usr/bin/env bash
# Pins every extension in programs.vscode.marketplaceExtensions to the newest
# release in the nix-vscode-extensions input that runs on the VS Code in
# nixpkgs. Prints "<id>: <old> -> <new>" for each one that moved.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PINS="$REPO_ROOT/diy-modules/vscode_marketplace.lock.json"

new="$(mktemp)"
trap 'rm -f "$new"' EXIT

nix --extra-experimental-features "nix-command flakes" \
  eval --raw "$REPO_ROOT#lib.vscodeMarketplacePins" > "$new"

# "<id> <version>" per pinned extension
versions() {
  sed -n 's/^  "\([^"]*\)": .*"version":"\([^"]*\)".*/\1 \2/p' "$1"
}

# the whole pin of one extension, without the comma between entries
pin() {
  grep -F "  \"$2\": " "$1" | sed 's/,$//'
}

if [ "$(versions "$new" | wc -l)" -ne "$(grep -c '^  "' "$new")" ]; then
  echo "vscode extensions: the generated pins do not look right, nothing written" >&2
  exit 1
fi

while read -r id version; do
  old="$(versions "$PINS" | awk -v id="$id" '$1 == id { print $2 }')"
  if [ -z "$old" ]; then
    echo "$id: new -> $version"
  elif [ "$old" != "$version" ]; then
    echo "$id: $old -> $version"
  elif [ "$(pin "$PINS" "$id")" != "$(pin "$new" "$id")" ]; then
    echo "$id: $version -> $version (re-pinned)"
  fi
done < <(versions "$new")

while read -r id version; do
  grep -q "^  \"$id\": " "$new" || echo "$id: $version -> removed"
done < <(versions "$PINS")

cat "$new" > "$PINS"
