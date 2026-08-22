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
    millennium = {
      url = "github:SteamClientHomebrew/Millennium?dir=packages/nix";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      unstable,
      sops-nix,
      millennium,
      spicetify-nix,
      ...
    }:

    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (import ./overlays { inherit unstable system; })
          inputs.millennium.overlays.default
        ];
      };
      diy = (import ./diy-packages { inherit pkgs; });

      mkHost =
        hostname: hardwareFile: extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system pkgs;

          specialArgs = {
            inherit inputs;
            unstable = import unstable {
              inherit system;
              config.allowUnfree = true;
            };
            inherit diy;
          };

          modules = [
            ./system
            ./imports
            hardwareFile
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs;
                  diy = diy;
                  unstable = import unstable {
                    inherit system;
                    config.allowUnfree = true;
                  };
                };
                users.artesia = import ./user/artesia;
                backupFileExtension = "backup";
              };
            }
          ]
          ++ extraModules;
        };
    in
    {
      nixosConfigurations.io = mkHost "io" ./system/per_host/io/hardware-configuration.io.nix [
        ./system/per_host/io
      ];

      nixosConfigurations.ganymedes = mkHost "ganymedes" ./system/per_host/ganymedes/hardware-configuration.ganymedes.nix [
        ./system/per_host/ganymedes
      ];

      nixosConfigurations.nymphe = mkHost "nymphe" ./system/per_host/nymphe/hardware-configuration.nymphe.nix [
        ./system/per_host/nymphe
      ];
    };
}
