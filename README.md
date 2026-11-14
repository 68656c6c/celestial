# Celestial

My NixOS stack: one flake, home-manager, niri with noctalia, or sway, four machines.

## Folder structure
```
  diy-modules     - custom options (host facts, disk layout, gpu, laptop, fastboot and bootsplash switches)
  diy-packages    - software not in nixpkgs, used as pkgs.diy.<name>
  disko           - the one disk layout every host uses (ESP, root, optional swap)
  docs            - how the repo fits together
  imports         - third-party modules every host loads
  installer       - bootable image that installs a host, new or existing
  overlays        - unstable versions of a few apps, and the diy package set
  scripts         - install, key, deploy and update helpers
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
`scripts/deploy.nu` does all of that, then commits and pushes once the switch went through. CI builds and caches; the other machines only download.

## CI
GitHub Actions builds every host on each push to `main` and pushes the closures to attic through Pangolin (`.github/workflows/build-hosts.yml`); pull requests are built without pushing. `update-flake.yml` bumps `flake.lock` every Monday and the two AppImage browsers every day, builds everything and opens a pull request per kind; merge it and the next switch is a download. Dependabot keeps the action pins current.

| Repository setting | What it is |
|---|---|
| secret `ATTIC_TOKEN` | attic token with pull and push rights. The cache is private; attic checks every request itself, so the Pangolin resource in front of it is public |
| secret `CACHIX_AUTH_TOKEN`, optional | push token for the public `celestial` cachix cache. With it, what CI builds also lands there, so an install or switch away from the lab network downloads instead of compiling |
| variable `ATTIC_PUBLIC_URL`, optional | where CI reaches attic, default `https://attic.artesia.cloud` |

Hosts pull with the `attic-netrc` entry in `secrets/secrets.yaml` once it is added; until then they build what the public caches lack.

## Installing a host
New machine or reinstall, it is the same stick. Download `celestial-installer.iso` from the [installer release](https://github.com/68656c6c/celestial/releases/tag/installer) (the `.sha256` next to it is for checking the download), `dd` it to a stick and boot it. The installer clones this repo when it runs, so the stick does not go stale when hosts change; CI only rebuilds it when `installer/` or the lock changes.

It asks everything before it touches the disk, then runs by itself:

1. Network. Ethernet just works. On a reinstall it reuses the wifi the old install knew. Otherwise it offers the `nmtui` wifi menu.
2. Host. A machine whose DMI product name is in some host's `host.dmi` is recognised. A new machine with a key stick prepared for it (below) takes its name from that key. A reinstall of a host without `host.dmi` goes by the install it finds on the disk. Otherwise it asks for a name: an existing one installs that host here, a new one creates the host. A new host is filled in from what the hardware reports (hardware file, DMI name, GPU, laptop or not, connected screens), so it is recognised by itself from then on.
3. Password, only when the host's age key cannot read the secrets yet. A reinstall keeps the key of the install it replaces (it asks for the old disk passphrase if that install is encrypted), so one stick is enough.
4. It shows the disk it is about to wipe and counts down 15 seconds.

Then disko, `nixos-install`, reboot. The repo ends up in `~/.dotfiles` with whatever was generated, ready to commit.

A new host logs in with the password typed in step 3 until its key is enrolled:
```
new host:           cd ~/.dotfiles, commit, push
any enrolled host:  git pull && scripts/rekey.sh, commit, push
new host:           git pull && nh os switch
```
Then fill in what cannot be detected (screen scale and positions, extra packages) in `system/per_host/<hostname>/`, and `sudo tailscale up` if it should be on the tailnet. Hosts are discovered from the folders under `system/per_host/`, there is no list to maintain.

### The key stick
Optional second stick, any filesystem labelled `CEL_KEYS` (`mkfs.vfat -n CEL_KEYS /dev/sdX1`). With the host's key on it the install asks nothing and the secrets work from the first boot.

| On the stick | What it does | How it gets there |
|---|---|---|
| `keys/<host>.luks` | the disk passphrase of a host with `host.disk.encrypt` | a text file with the passphrase. Plain text next to the age key: whoever has the stick has the disk, so take it off again after the install |
| `keys/<host>.key` | the host's age key | `scripts/key-stick.sh <mountpoint>` on that host before wiping it, or `scripts/key-stick.sh <mountpoint> <newhost>` on any enrolled host to make and enroll a key for a machine that does not exist yet (commit and push after) |
| `wifi/*.nmconnection` | wifi without the menu | `sudo cp /etc/NetworkManager/system-connections/<name>.nmconnection` from a machine that knows the network |
| `attic.netrc` | pull from the private cache during the install | one line, `machine attic.artesia.cloud password <pull token>` |
| `celestial.bundle` | install commits that are not pushed | `git bundle create celestial.bundle HEAD main` |

### Encrypted disk and Secure Boot
Two per-host switches, both for a fresh install: `host.disk.encrypt` puts the root in LUKS (swap gets a throwaway key per boot) and `host.secureboot.enable` has lanzaboote sign the boot files with keys the installer creates in `/var/lib/sbctl`. The installer asks for the disk's recovery passphrase, or reads it from `keys/<host>.luks` on the key stick. A pre-switch check refuses to apply either to an install that was not made for it.

After the install, `scripts/secure-host.sh` finishes the job; it looks at the machine's state and does or names the next step, so run it after each reboot:
```
1. first boot: type the disk passphrase, log in, run scripts/secure-host.sh. It says how to put the firmware in setup mode
2. back from the firmware: scripts/secure-host.sh enrolls the keys, reboot (Secure Boot is now on)
3. scripts/secure-host.sh binds the disk to the TPM, sealed to the Secure Boot state. From here it unlocks by itself
```
The passphrase stays valid. If a firmware update makes the disk ask for it again, `scripts/secure-host.sh --again` binds the TPM anew.

### Trying it first
`scripts/test-installer.sh` builds the image and boots it in a VM with an empty disk, installing the current commit. With a DMI product name as argument (`scripts/test-installer.sh "Predator G9-791"`) the VM poses as that machine.

### Converting a machine that already runs NixOS
Clone the repo to `~/.dotfiles` and run `scripts/setup-host.sh <hostname>`, the same script the installer uses. It tells you what is left: `scripts/label-disk.sh` so the existing partitions carry the GPT labels the mount table expects (only labels are written; root, the ESP and the active swap partition, zram is skipped), then `nh os switch .#<hostname>`. Label before switching: otherwise the next boot waits for `disk-main-root`, and the way back is the previous generation (hold Space for the boot menu on fastboot hosts).

Anyone could clone and use this, but my secrets have no use to you and the structure is whatever made sense to me at the time.

## AI use
The original concept and setup were designed by me, but in the age of AI, and wanting to understand its use in software, this is one of the projects I decided to use AI with. My stance on AI is honestly pretty black and white: I wish not to use it. Unfortunately, in an age of ever increasing productivity, having to cater to that is one of the sacrifices I have to accept.

That does mean more AI-assisted programming will be done here in the future, but only when I feel comfortable with whatever the AI will be writing. I spent weeks learning the Nix language and how it is structured before I even thought AI would be a remotely good idea. And even then it is rather verbose, and it becomes really hard to make sure that everything is in order.

All in all, I would always love to discuss the ethics of AI use. What I do stand heavily against is generative AI, and having conversations or thoughts with AI: it forces you to adapt to the mental image and language of the AI itself, instead of using what you know from growing up and the cultural environment around you to add your own unique touch to the world. That, and critical thinking honestly going backwards, because people are using AI as a replacement for thought instead of as assistance. It is a scary time right now.

So: scripts, modules, CI and these docs have AI-written parts. I review what goes in and it runs on my own machines, but read it with the same suspicion as any config you did not write.
