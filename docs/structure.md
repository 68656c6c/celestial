# Structure

This repo is the complete configuration for my Linux machines. Each machine runs NixOS, a Linux distribution where the whole system is described in code: installed software, services, users, desktop settings and dotfiles. Applying the repo to a machine builds that description and switches to it, so every machine can be rebuilt from scratch to the same state, and every change is a git commit that can be rolled back.

## Terms used in this document

| Term | What it is |
|---|---|
| Nix | The package manager and configuration language everything here is written in. Files end in `.nix`. |
| nixpkgs | The official Nix package collection. "Stable" is the twice-yearly release (26.05 here), "unstable" is the rolling branch with newer versions. |
| Module | A `.nix` file that sets configuration values, or defines new settings other files can set. NixOS merges all modules into one system configuration. |
| Flake | The entry point of a Nix project (`flake.nix`). Declares external dependencies with pinned versions (`flake.lock`) and what the project builds. |
| home-manager | A Nix tool for the user's own settings and dotfiles (shell, editor, terminal), as opposed to system-wide settings. |
| Overlay | A rule that changes the package set, for example "use the unstable version of this app" or "add these extra packages". |
| sops / age | Encryption for secrets stored in git. Each machine has its own private key and can only decrypt the files it is allowed to. |
| attic | A self-hosted binary cache. Machines download finished builds from it instead of compiling locally. |
| Forgejo | The self-hosted git server this repo lives on, with GitHub Actions-style CI. |
| Wayland compositor | The component that draws windows and handles input on a modern Linux desktop. niri (scrolling columns) and sway (classic tiling) are the two used here. |
| noctalia | The desktop shell on top of niri: status bar, app launcher, notifications, lock screen, wallpaper rotation. |
| Tailscale | A mesh VPN. The daemon runs on every machine, joining the network is a manual step. |

## How a machine is built

`flake.nix` treats every folder under `system/per_host/` as a machine and builds each with the same recipe (`mkHost`). Every machine gets the same shared layers; the only things that differ are its hardware file and its own folder.

```mermaid
flowchart TD
    flake["flake.nix<br/>entry point"]
    hosts["system/per_host/*<br/>one folder per machine: io, ganymedes, nymphe, aphrodite"]
    mkHost{{"mkHost<br/>build recipe, once per machine"}}

    flake --> hosts --> mkHost

    subgraph pkgset["Package set"]
        nixpkgs["nixpkgs stable 26.05"]
        overlays["overlays/<br/>newer versions of selected apps<br/>+ diy-packages/ as pkgs.diy"]
        millennium["Millennium overlay<br/>Steam plugin loader"]
        nixpkgs --> overlays --> millennium
    end

    flake --> pkgset
    pkgset --> mkHost

    subgraph nixos["System configuration"]
        system["system/<br/>baseline for every machine"]
        imports["imports/<br/>third-party modules"]
        diymods["diy-modules/<br/>custom settings"]
        hw["hardware file<br/>disks, drivers, generated"]
        perhost["system/per_host/name/<br/>what makes this machine different"]
        imports --> diymods
    end

    mkHost --> system & imports & hw & perhost

    subgraph hm["User configuration via home-manager"]
        user["user/artesia/"]
        uimports["imports/<br/>third-party user modules"]
        programs["programs/<br/>one file per application"]
        ucfg["user_artesia_configuration.nix<br/>cursor, theme, portals"]
        user --> uimports & programs & ucfg
    end

    mkHost --> hm
    perhost -.->|"monitors, cursor size,<br/>laptop switch, compositor"| diymods
    diymods -.->|"read by"| programs
```

`diy-modules/` and `user/artesia/programs/` load every `.nix` file in their folder automatically, so adding a file is enough. `system/` and `system/per_host/<name>/` list their files explicitly.

## What each layer is for

The short version: the shared layers describe what every machine has, the per-machine layer describes what makes one machine different, and the custom modules define the settings the per-machine layer fills in.

### system/: the baseline

What every machine gets regardless of hardware: boot loader, networking and firewall, timezone and language, the `artesia` user account, audio, Bluetooth, the login screen, Steam, fonts, Tailscale, automatic cleanup of old builds, the sops key location and the address of the binary cache.

It is split into four files by kind so it is always clear where something lives: `configurations` (general system settings), `packages` (installed software), `programs` (applications that need system integration, such as Steam or a compositor) and `services` (background daemons).

### system/per_host/\<name\>/: per machine

The baseline cannot know what hardware a machine has or what it is used for, so each machine has its own folder with the same four-file split. This is where a desktop and a laptop diverge:

| Machine | Type | Compositor | What makes it different |
|---|---|---|---|
| io | desktop | niri | NVIDIA graphics card with a driver tweak to limit video memory use, three monitors, Sunshine (a remote desktop and game streaming server) reachable on its LAN address, a USB label printer, virtual machine tools, 3D and image editing software, a Windows boot entry |
| ganymedes | laptop | niri and sway | single built-in screen, laptop power management, fixed public DNS servers |
| nymphe | laptop | sway only | built to run on very little: no xwayland, foot instead of ghostty, waybar and fuzzel instead of noctalia, no Discord presence or cache uploader in the background, fast boot (nixos-init, `/etc` overlay, userborn, zero boot menu timeout), screen scaled to 125%, smaller cursor, login password from an encrypted secret, laptop power management |
| aphrodite | laptop | niri | single built-in screen, AMD so no thermald, laptop power management |

A per-machine file can also override the baseline. nymphe, for example, swaps its user's terminal and turns off a few user services, without touching the shared files.

Each folder also holds `hardware-configuration.<name>.nix`. It is generated by the NixOS installer and describes disks, filesystems and kernel drivers. It gets regenerated, not edited by hand.

### diy-modules/: custom settings

NixOS comes with thousands of settings, but none for facts like "this laptop has one 1080p screen at 125% scale". Without a place to record that, every application that cares about screens would need its own per-machine copy of it, or the shared files would fill up with "if machine is X" checks. These modules add the missing settings. There are three kinds:

**Machine facts** (`host.monitors`, `host.cursor`) do nothing by themselves. They give each machine a single, validated place to state a fact, and the user configuration reads it back. This is the main link between the per-machine layer and the user layer.

**Feature switches** (`host.laptop`) bundle several related settings behind one on/off switch. Turning on `host.laptop` enables TLP for battery life, zram swap, and makes the weekly store cleanup and optimisation wait for mains power. TLP's `tlp-pd` provides the power-profiles-daemon interface, so the power profile widgets in noctalia and waybar keep working and the real power-profiles-daemon is turned off. `host.laptop.thermald` is on by default and off on AMD machines.

**Always on** (`ca_certificates.nix`) has no switch. It makes every machine trust the internal certificate authorities kept in a separate private repo, so internal HTTPS services work without browser warnings.

An example from start to finish: io's per-machine file lists three monitors. The niri config in `user/artesia/programs/` reads that list and writes one `output` block per monitor with its mode, position and scale. nymphe lists one monitor and gets one block. The niri file is the same on both.

### imports/: third-party modules

Modules written by other projects: home-manager (user configuration), sops-nix (secret decryption) and the noctalia desktop shell module. It also loads `diy-modules/`. Kept apart from `system/` because these files define new settings, while `system/` only fills settings in.

### diy-packages/: software not in nixpkgs

Applications that the official package collection does not have, or not in a usable form: two custom mouse cursor themes, the Helium and Zen web browsers, a CUPS driver for the Citizen label printer built from the vendor's source tarball, and a container image for the CI runner. The overlay exposes them as `pkgs.diy.<name>`, for example io's printer setup uses `pkgs.diy.cups-citizen-ctzcls`. `scripts/update-appimages.sh` bumps the two browsers to their latest release.

### overlays/: newer versions of selected apps

The machines run the stable package collection, which only gets security and bug fixes between releases. For a few applications that move fast or where newer features matter, this overlay swaps in the version from the unstable branch instead. Because it replaces the package for the whole system, every place that refers to it gets the newer version, with no changes needed elsewhere. The same overlay is where `pkgs.diy` comes from.

Currently swapped: the nushell shell, atuin (shell history sync), flameshot (screenshots), hyprpicker (colour picker), the noctalia desktop shell, the Bitwarden password manager, two AI coding assistants (Claude Code and opencode) and the Pangolin tunnel client.

For a single application that only one config file uses, refer to it as `unstable.<name>` in that file instead of adding it here.

### user/artesia/: the user's own settings

Everything home-manager manages for the `artesia` user: one file per application under `programs/` (shell, text editor, terminal, compositors, git, SSH), the Spotify theming module under `imports/`, and the mouse cursor theme, GTK theme and desktop portals in `user_artesia_configuration.nix`. This layer is the same on every machine. Machine-specific values come in through the custom settings above, or through an override in the machine's own folder.

The two compositor files are gated on the host: `niri.nix` only applies where the machine enables `programs.niri`, `sway.nix` only where it enables `programs.sway`. niri starts noctalia; sway brings its own waybar, fuzzel, mako and swaylock. Both know the same keys (Super+Q terminal, Super+E files, Super+C close, Super+Space launcher, Super+L lock, media and brightness keys, Print for a screenshot) and both float the flameshot capture window over the whole screen instead of tiling it.

### Where does a change go?

| Change | File |
|---|---|
| Something every machine should have | `system/system_<kind>.nix` |
| Something only one machine needs | `system/per_host/<name>/<name>_<kind>.nix` |
| A new machine | a folder under `system/per_host/`, via `scripts/setup-host.sh` |
| A machine fact the user configuration needs | new setting in `diy-modules/host_*.nix`, set it per machine, read it in `user/` |
| A feature some machines switch on, with several parts | feature switch in `diy-modules/`, like `host.laptop` |
| An application's own settings | `user/artesia/programs/<application>.nix` |
| Software the official collection lacks | `diy-packages/`, plus a line in its `default.nix` |
| A newer version of an app on every machine | `overlays/default.nix` |

## Secrets and delivery

```mermaid
flowchart LR
    subgraph repo["Repo"]
        sopscfg[".sops.yaml<br/>every machine key + backup key"]
        secrets["secrets/secrets.yaml<br/>readable by every machine"]
        sopscfg --> secrets
    end

    setup["scripts/setup-host.sh<br/>onboard a new machine"] -->|"hardware file, age key,<br/>per-host folder, key entries"| repo

    deploy["scripts/deploy.nu<br/>nix fmt, nix flake check,<br/>commit, push"] --> main[("main branch on Forgejo")]
    deploy -->|"apply config"| local["current machine"]
    local -->|"upload build"| attic[("attic binary cache")]

    main -->|"on push"| ci["CI: build-hosts.yml<br/>lint, then build"]
    ci -->|"build every machine,<br/>skip what is already cached"| attic
    gc["CI: gc-runner-store.yml<br/>Sundays 04:00"] -.->|"delete old builds"| runner["CI runner disk"]
    upd["CI: update-flake.yml<br/>Mondays 05:00"] -->|"nix flake update,<br/>build every machine"| attic
    upd -->|"pull request with the new lock"| main

    attic -->|"download prebuilt"| hostsbox["io / ganymedes / nymphe / aphrodite"]
    secrets -->|"decrypted when the config is applied<br/>with /var/lib/sops-nix/key"| hostsbox
```

Secrets are stored encrypted in git. `.sops.yaml` lists each machine's public key; the single secrets file is readable by every machine, and a backup key can read everything so secrets survive a lost machine. Every machine keeps its private key at `/var/lib/sops-nix/key`. Only nymphe currently uses a secret (its login password), the other machines decrypt nothing, but they all have a key so a secret can be added without onboarding work. aphrodite's key still needs adding to `.sops.yaml`.

A normal change goes through `deploy.nu`: `nix fmt` formats, `nix flake check` runs deadnix and a format check, then commit, push, apply the new configuration to the current machine and upload the result to the cache. The push also triggers CI, which runs the same check and then builds every machine's configuration and uploads anything not yet cached. When another machine updates, it downloads those builds instead of compiling them itself.

Dependency updates are CI's job too. Every Monday `update-flake.yml` runs `nix flake update`, lints, builds every machine and uploads the results, then opens a pull request on the `update/flake-lock` branch with the list of changed inputs. If the build fails there is no pull request, only a red run. Merging the pull request is the whole upgrade; the machines download what CI already built.

The certificate repo (`trusted-certificates`) is private and only reachable on the lab network, which is why CI first switches to the lab's DNS server and uses an access token to fetch it.
