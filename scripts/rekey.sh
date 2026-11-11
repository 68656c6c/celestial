#!/usr/bin/env bash
# Re-encrypt secrets.yaml for the keys listed in .sops.yaml. Run on a machine
# whose key can already read the secrets, after a new host added its key
# (git pull first), then commit and push.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key sops updatekeys --yes secrets/secrets.yaml
sudo chown "$(id -u):$(id -g)" secrets/secrets.yaml
git --no-pager diff --stat -- secrets/secrets.yaml
