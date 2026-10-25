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
    # CachyOS kernels, prebuilt against their own nixpkgs (no follows on purpose)
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
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
      self,
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
              };
            }
          ];
        };

      nixosConfigurations = lib.genAttrs hosts mkHost;

      # Bootable image that installs one of the hosts above, unattended.
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
          {
            celestial.installer = {
              flake = self;
              hosts = lib.mapAttrs (_: host: {
                inherit (host.config.host) dmi;
                inherit (host.config.host.disk) layout swapSize espSize;
              }) nixosConfigurations;
            };
          }
        ];
      };

      nixFiles = lib.fileset.toSource {
        root = ./.;
        fileset = lib.fileset.fileFilter (file: file.hasExt "nix") ./.;
      };
    in
    {
      formatter.${system} = pkgs.nixfmt-tree;

      packages.${system}.installer-iso = installer.config.system.build.isoImage;

      checks.${system}.lint =
        pkgs.runCommand "celestial-lint"
          {
            nativeBuildInputs = with pkgs; [
              deadnix
              nixfmt
            ];
          }
          ''
            cd ${nixFiles}
            deadnix --fail --no-lambda-arg .
            find . -name '*.nix' -exec nixfmt --check {} +
            touch $out
          '';

      inherit nixosConfigurations;
    };
}
