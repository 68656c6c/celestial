{
  config,
  pkgs,
  lib,
  diy,
  osConfig,
  ...
}:

{
  home.username = "artesia";
  home.homeDirectory = "/home/artesia";
  home.pointerCursor = {
    enable = true;
    package = diy.kasane-teto-cursor-linux;
    hyprcursor.enable = true;
    gtk.enable = true;
    x11.enable = true;
    name = "kasane-teto-cursor-linux";
    size = osConfig.host.cursor.size;
  };
  home.sessionVariables = {
    NIXOS_OZONE_WL = 1;
    NH_OS_FLAKE = "/home/artesia/.dotfiles";
    XCURSOR_SIZE = osConfig.host.cursor.size;
  };

  services.arrpc.enable = true;
  services.arrpc.systemdTarget = "graphical-session.target";

  gtk = {
    gtk4.theme = null;
    enable = true;
    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3-dark";
    };
    iconTheme = {
      package = pkgs.morewaita-icon-theme;
      name = "MoreWaita";
    };
    font = {
      name = "Atkinson Hyperlegible Next";
      size = 11;
    };
  };

  xdg.autostart.enable = true;

  xdg.portal = {
    enable = lib.mkDefault true;
    config = {
      common = {
        default = [
          "hyprland"
          "gtk"
          "gnome"
        ];
        "org.freedesktop.appearance" = {
          color-scheme = "prefer-dark";
        };
      };
      hyprland = {
        default = [
          "hyprland"
          "gtk"
          "gnome"
        ];
        "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
      };
    };
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
  };

  home.stateVersion = "25.05"; # Have you read da comment?
}
