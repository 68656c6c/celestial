# Structure

## How a host is built

`flake.nix` reads `system/hosts.nix` and calls `mkHost` once per entry. Every host gets the same shared stack; the only per-host inputs are its hardware file and its `per_host/<name>` directory.

```mermaid
flowchart TD
    flake[flake.nix]
    hosts[system/hosts.nix<br/>io, ganymedes, nymphe]
    mkHost{{mkHost name}}

    flake --> hosts --> mkHost

    subgraph pkgset[pkgs]
        nixpkgs[nixpkgs 26.05]
        overlays[overlays/<br/>pulls hyprland, nushell, claude-code etc. from unstable]
        millennium[millennium overlay]
        nixpkgs --> overlays --> millennium
    end

    diypkgs[diy-packages/<br/>cursors, helium, zen, cups-citizen, runner-image]

    flake --> pkgset
    pkgset --> diypkgs
    pkgset --> mkHost
    diypkgs -->|"specialArgs.diy"| mkHost

    subgraph nixos[NixOS modules]
        system[system/<br/>system_configurations, _packages, _programs, _services]
        imports[imports/<br/>home-manager, sops-nix, noctalia module]
        diymods[diy-modules/<br/>host.monitors, host.cursor, vpn.*, ca certs]
        hw[per_host/name/hardware-configuration.name.nix]
        perhost[per_host/name/<br/>name_configurations, _packages, _programs, _services]
        imports --> diymods
    end

    mkHost --> system & imports & hw & perhost

    subgraph hm[home-manager: users.artesia]
        user[user/artesia/]
        uimports[imports/<br/>spicetify]
        programs[programs/<br/>auto-imports every .nix<br/>hyprland, niri, sway, nushell, helix, ghostty...]
        ucfg[user_artesia_configuration.nix]
        user --> uimports & programs & ucfg
    end

    mkHost --> hm
    perhost -.->|"sets host.monitors / host.cursor"| diymods
    diymods -.->|"read by"| programs
```

`diy-modules/` and `user/artesia/programs/` both import every `.nix` in their directory, so dropping a file in is enough. `system/` and `per_host/<name>/` use explicit import lists.

## Secrets and delivery

```mermaid
flowchart LR
    subgraph repo[repo]
        sopscfg[.sops.yaml<br/>age key per host + backup]
        secrets[secrets/<br/>secrets.yaml: all hosts<br/>vpn_name.ovpn: that host only]
        sopscfg --> secrets
    end

    setup[scripts/setup-host.sh] -->|"hardware config, age key,<br/>hosts.nix + .sops.yaml entries"| repo

    deploy[scripts/deploy.nu<br/>nixfmt, deadnix, commit, push] --> main[(main on Forgejo)]
    deploy -->|"nh os switch"| local[current host]
    local -->|"attic push"| attic[(attic: celestial)]

    main -->|"push"| ci[build-hosts.yml<br/>runs-on: nix]
    ci -->|"scripts/build-hosts.sh<br/>skips toplevels already cached"| attic
    gc[gc-runner-store.yml<br/>Sundays 04:00] -.->|"nix-collect-garbage"| runner[runner store]

    attic -->|"substituter"| hostsbox[io / ganymedes / nymphe]
    secrets -->|"sops-nix decrypts at activation<br/>with /etc/sops-age/keys"| hostsbox
```

The `trusted-certificates` input is a private repo on `git.artesia.cloud`, which is why CI rewrites the SSH URL to HTTPS with `FLAKE_TOKEN` and switches to the lab resolver before checkout.
