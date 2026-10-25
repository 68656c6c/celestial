# Celestial

My NixOS stack: one flake, home-manager, niri or sway with noctalia, four machines.

## Folder structure
```
  diy-modules     - custom options (host facts, laptop switch, lab CA trust)
  diy-packages    - software not in nixpkgs, used as pkgs.diy.<name>
  docs            - how the repo fits together
  imports         - third-party modules every host loads
  overlays        - unstable versions of a few apps, and the diy package set
  scripts         - setup, deploy and update helpers
  secrets         - sops-encrypted, only readable by my machines
  system          - the shared baseline and one folder per host
  user            - home-manager config for the artesia user
  wallpapers      - rotated by noctalia
```

See [docs/structure.md](docs/structure.md) for the long version.

## Daily use
```
nix fmt            # format every .nix file
nix flake check    # deadnix + nixfmt --check, CI runs this before building
nh os switch       # apply to the current machine
```
`scripts/deploy.nu` does all of that plus commit, push and a push to the attic cache.

## CI
GitHub Actions builds every host on each push to `main` and pushes the closures to attic through Pangolin (`.github/workflows/build-hosts.yml`); pull requests are built without pushing. `update-flake.yml` bumps `flake.lock` every Monday and the two AppImage browsers every day, builds everything and opens a pull request per kind; merge it and the next switch is a download. Dependabot keeps the action pins current.

Repository secrets: `ATTIC_TOKEN` (attic token with push rights), `PANGOLIN_ACCESS_TOKEN_ID` and `PANGOLIN_ACCESS_TOKEN` (a shareable link on the attic resource). Optional variable `ATTIC_PUBLIC_URL`, default `https://attic.artesia.cloud`.

## Adding a host
1. Install git and nh and clone the repo to `~/.dotfiles`
2. Delete `/etc/nixos/configuration.nix`
3. Run `scripts/setup-host.sh <hostname>`. It generates the hardware file, the age key at `/var/lib/sops-nix/key`, the per-host folder and the `.sops.yaml` entries
4. Fill in monitors, DNS and `host.laptop.enable` in `system/per_host/<hostname>/<hostname>_configurations.nix`
5. `sops updatekeys secrets/secrets.yaml`, then `nh os switch .#<hostname>`
6. `sudo tailscale up` once if the machine should be on the tailnet

Hosts are discovered from the folders under `system/per_host/`, there is no list to maintain.

Anyone could clone and use this, but my secrets have no use to you and the structure is whatever made sense to me at the time.
