{ pkgs, ... }:
{
  miku-cursor-linux = pkgs.callPackage ./miku-cursor-linux.nix { };
  kasane-teto-cursor-linux = pkgs.callPackage ./kasane-teto-cursor-linux.nix { };
  cups-citizen-ctzcls = pkgs.callPackage ./cups-citizen-ctzcls.nix { };
  helium = pkgs.callPackage ./helium.nix { };
  zen-browser = pkgs.callPackage ./zen-browser.nix { };
}
