{
  config,
  pkgs,
  lib,
  osConfig,
  ...
}:

{
  home.username = "artesia";
  home.homeDirectory = "/home/artesia";
  home.pointerCursor = {
    enable = true;
    package = pkgs.diy.kasane-teto-cursor-linux;
    gtk.enable = true;
    x11.enable = true;
    name = "kasane-teto-cursor-linux";
    size = osConfig.host.cursor.size;
  };
  home.sessionVariables = {
    NIXOS_OZONE_WL = 1;
    NH_OS_FLAKE = "${config.home.homeDirectory}/.dotfiles";
    WLR_NO_HARDWARE_CURSORS = 1;
    XCURSOR_SIZE = osConfig.host.cursor.size;
  };

  services = {
    arrpc = {
      enable = true;
      systemdTarget = "graphical-session.target";
    };
  };

  gtk = {
    gtk4.theme = null;
    enable = true;
    gtk3.extraCss = ''
      @import url("noctalia.css");
    '';
    gtk4.extraCss = ''
      @import url("noctalia.css");
    '';
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
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
      niri = {
        default = [
          "gnome"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
    };
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
      gnome-keyring
    ];
  };

  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
}
