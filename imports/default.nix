{ inputs, ... }:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    inputs.disko.nixosModules.disko
    "${inputs.unstable}/nixos/modules/programs/wayland/noctalia.nix"
    ../diy-modules
  ];
}
