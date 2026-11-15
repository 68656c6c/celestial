{
  description = "I just work here";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-26.05/nixexprs.tar.zst";
    unstable.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Secure Boot: signs the boot files with the machine's own keys
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pre-commit.follows = "";
    };
    # CachyOS kernels, prebuilt against their own nixpkgs (no nixpkgs follows on purpose)
    chaotic = {
      url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
      inputs.home-manager.follows = "home-manager";
    };
    millennium = {
      url = "github:SteamClientHomebrew/Millennium?dir=packages/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Floating windows that follow the active workspace (niri has no sticky windows)
    niri-float-sticky = {
      url = "github:probeldev/niri-float-sticky";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      unstable,
      ...
    }:

    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;

      unstablePkgs = import unstable {
        inherit system;
        config.allowUnfree = true;
      };

      overlays = [
        (import ./overlays {
          unstable = unstablePkgs;
          niri-float-sticky = inputs.niri-float-sticky.packages.${system}.default;
        })
        inputs.millennium.overlays.default
      ];

      # Only for the flake's own outputs (packages, checks, formatter).
      # Hosts build their package set through the nixpkgs module below.
      pkgs = import nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
      };

      # Every directory under system/per_host is a host.
      hosts = lib.attrNames (
        lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./system/per_host)
      );

      mkHost =
        name:
        lib.nixosSystem {
          specialArgs = {
            inherit inputs;
            unstable = unstablePkgs;
          };

          modules = [
            {
              nixpkgs = {
                hostPlatform = system;
                config.allowUnfree = true;
                inherit overlays;
              };
            }
            ./system
            ./imports
            ./system/per_host/${name}/hardware-configuration.${name}.nix
            ./system/per_host/${name}
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                # activate at login instead of during the switch
                startAsUserService = true;
                extraSpecialArgs = {
                  inherit inputs;
                  unstable = unstablePkgs;
                };
                users.artesia = import ./user/artesia;
                backupFileExtension = "backup";
                overwriteBackup = true;
              };
            }
          ];
        };

      nixosConfigurations = lib.genAttrs hosts mkHost;

      # Bootable image that installs one of the hosts above, or creates a new
      # one. It clones this repo when it runs, so it only needs rebuilding when
      # installer/ or the lock changes.
      installer = lib.nixosSystem {
        specialArgs = {
          inherit inputs;
        };
        modules = [
          {
            nixpkgs = {
              hostPlatform = system;
              config.allowUnfree = true;
            };
          }
          ./installer
        ];
      };

      lintFiles = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.fileFilter (
          file: file.hasExt "nix" || file.hasExt "sh" || file.hasExt "yml"
        ) ./.;
      };
    in
    {
      formatter.${system} = pkgs.nixfmt-tree;

      packages.${system}.installer-iso = installer.config.system.build.isoImage;

      # What the installer needs to know about each host: which machine it is
      # and how its disk is laid out. `nix eval --json .#lib.hostFacts`
      lib.hostFacts = lib.mapAttrs (_: host: {
        inherit (host.config.host) dmi disk;
        secureboot = host.config.host.secureboot.enable;
      }) nixosConfigurations;

      checks.${system}.lint =
        pkgs.runCommand "celestial-lint"
          {
            nativeBuildInputs = with pkgs; [
              deadnix
              nixfmt
              shellcheck
              actionlint
            ];
          }
          ''
            cd ${lintFiles}
            deadnix --fail --no-lambda-arg .
            find . -name '*.nix' -exec nixfmt --check {} +
            # install.sh has no shebang, writeShellApplication supplies it
            find . -name '*.sh' -exec shellcheck --shell=bash {} +
            actionlint .github/workflows/*.yml
            touch $out
          '';

      inherit nixosConfigurations;
    };
}
