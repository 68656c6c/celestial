{ lib, ... }:

{
  programs = {
    sway = {
      enable = true;
      xwayland.enable = false;
    };
    hyprland.enable = lib.mkForce false;
  };
}
