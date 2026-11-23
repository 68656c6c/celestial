{ inputs, ... }:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    inputs.disko.nixosModules.disko
    inputs.lanzaboote.nixosModules.lanzaboote
    "${inputs.unstable}/nixos/modules/programs/wayland/noctalia.nix"
    "${inputs.unstable}/nixos/modules/programs/wayland/umbriel.nix"
    ../diy-modules
  ];
}
