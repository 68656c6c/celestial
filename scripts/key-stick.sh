#!/usr/bin/env bash
# Put a host's age key on the key stick, so the installer finds it and the
# install needs no password and no enrolling afterwards.
#
#   key-stick.sh <stick>          this machine's key, for reinstalling it
#   key-stick.sh <stick> <host>   a new key for a host that has none yet. It is
#                                 added to .sops.yaml and secrets.yaml here, so
#                                 run it on an enrolled machine, then commit
#                                 and push before installing
#
# <stick> is where the stick is mounted. Its filesystem must carry the label
# CEL_KEYS (mkfs.vfat -n CEL_KEYS /dev/sdX1). Optional extras the
# installer also reads from it: wifi/*.nmconnection, attic.netrc.
set -euo pipefail

STICK="${1:?Usage: $0 <stick mountpoint> [host]}"
HOST="${2:-$(hostname)}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOPS_FILE="$REPO_ROOT/.sops.yaml"

[ -d "$STICK" ] || { echo "$STICK is not a directory" >&2; exit 1; }
mkdir -p "$STICK/keys"
target="$STICK/keys/$HOST.key"

if [ "$HOST" = "$(hostname)" ]; then
  sudo cat /var/lib/sops-nix/key | install -m 600 /dev/stdin "$target"
  echo "this machine's key -> $target"
  exit 0
fi

if grep -q "&host_$HOST " "$SOPS_FILE"; then
  echo "$HOST already has a key in .sops.yaml. Run this on $HOST itself to copy it," >&2
  echo "or install without one: the installer makes a new key and asks for a password." >&2
  exit 1
fi

age-keygen -o "$target" 2>/dev/null
pubkey="$(age-keygen -y "$target")"
sed -i "/^  - &backup /i\\  - &host_$HOST $pubkey" "$SOPS_FILE"
sed -i "/^  all: &all$/a\\    - *host_$HOST" "$SOPS_FILE"
"$REPO_ROOT/scripts/rekey.sh"

echo
echo "new key for $HOST -> $target"
echo "commit and push .sops.yaml and secrets/secrets.yaml, then boot the installer with this stick plugged in"
