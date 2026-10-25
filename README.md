# Celestial

My NixOS stack: one flake, home-manager, niri with noctalia, or sway, four machines.

## Folder structure
```
  diy-modules     - custom options (host facts, disk layout, gpu, laptop and fastboot switches)
  diy-packages    - software not in nixpkgs, used as pkgs.diy.<name>
  disko           - the one disk layout every host uses (ESP, root, optional swap)
  docs            - how the repo fits together
  imports         - third-party modules every host loads
  installer       - bootable image that installs a host unattended
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
`scripts/deploy.nu` does all of that plus commit and push. CI builds and caches; the machines only download.

## CI
GitHub Actions builds every host on each push to `main` and pushes the closures to attic through Pangolin (`.github/workflows/build-hosts.yml`); pull requests are built without pushing. `update-flake.yml` bumps `flake.lock` every Monday and the two AppImage browsers every day, builds everything and opens a pull request per kind; merge it and the next switch is a download. Dependabot keeps the action pins current.

Repository secret: `ATTIC_TOKEN` (attic token with pull and push rights; the cache is private, attic gates everything, the Pangolin resource in front is public). Optional variable `ATTIC_PUBLIC_URL`, default `https://attic.artesia.cloud`. Hosts get their pull token from the `attic-netrc` entry in `secrets/secrets.yaml` once it is added; until then they build what the public caches lack.

## Reinstalling a host
Download `celestial-installer.iso` from the [installer release](https://github.com/68656c6c/celestial/releases/tag/installer) (rebuilt by CI on every change to the installer, the disk layout or the lock; the `.sha256` next to it is for checking the download), `dd` it to a stick, boot it with ethernet plugged in. It matches the machine to a host by DMI product name (`host.dmi`), shows the disk it is about to wipe, counts down 15 seconds, then partitions with disko and installs. If a second stick labelled `CELESTIAL_KEYS` holds `keys/<host>.key`, that becomes the host's age key and the login password comes from the secrets; an `attic.netrc` on the same stick lets the install pull from the private cache. Otherwise a key is generated, you set a password once, and the printed public key goes into `.sops.yaml`.

Machines installed before disko mount by UUID. Run `sudo nix shell nixpkgs#gptfdisk -c scripts/label-disk.sh` on them once, before switching to a configuration from this point on; it only writes GPT partition labels, for root, the ESP and the active swap partition (zram is skipped).

## Adding a host
1. Boot any NixOS installer, install git and nh, clone the repo to `~/.dotfiles`
2. Run `scripts/setup-host.sh <hostname>`. It generates the hardware file (no filesystems, disko owns those), the age key at `/var/lib/sops-nix/key`, the per-host folder with the machine's DMI name, and the `.sops.yaml` entries
3. Fill in monitors, DNS, `host.disk.layout`, `host.gpu`, `host.laptop.enable` and `host.fastboot.enable` in `system/per_host/<hostname>/<hostname>_configurations.nix`
4. `sops updatekeys secrets/secrets.yaml`, commit, then reinstall from the stick or `nh os switch .#<hostname>` after `scripts/label-disk.sh`
5. `sudo tailscale up` once if the machine should be on the tailnet

Hosts are discovered from the folders under `system/per_host/`, there is no list to maintain.

Anyone could clone and use this, but my secrets have no use to you and the structure is whatever made sense to me at the time.
