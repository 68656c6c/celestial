{ pkgs, ... }:
{
  miku-cursor-linux = pkgs.callPackage ./miku-cursor-linux.nix { };
  kasane-teto-cursor-linux = pkgs.callPackage ./kasane-teto-cursor-linux.nix { };
  cups-citizen-ctzcls = pkgs.callPackage ./cups-citizen-ctzcls.nix { };
}
