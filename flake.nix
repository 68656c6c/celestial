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
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
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
      hosts = import ./system/hosts.nix;
      unstablePkgs = import unstable {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (import ./overlays { unstable = unstablePkgs; })
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
            unstable = unstablePkgs;
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
                  unstable = unstablePkgs;
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
      nixosConfigurations = nixpkgs.lib.mapAttrs' (name: _: {
        name = name;
        value = mkHost name ./system/per_host/${name}/hardware-configuration.${name}.nix [
          ./system/per_host/${name}
        ];
      }) hosts;

      packages.x86_64-linux = diy // {
        inherit (pkgs)
          millennium-steam
          stremio-linux-shell
          kasane-teto-linux-cursor
          ;
      };
    };
}
