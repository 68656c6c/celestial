{ inputs, ... }:

{
  imports = [
    inputs.spicetify-nix.homeManagerModules.spicetify
  ];
}
