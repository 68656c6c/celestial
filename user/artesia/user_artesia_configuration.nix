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

  # Zen reads native messaging manifests from ~/.mozilla, like Firefox, but
  # keeps its profile in ~/.config/zen. Bitwarden only writes its browser
  # integration manifest when ~/.mozilla exists, so without this the extension
  # can never reach the desktop app for biometric unlock.
  systemd.user.tmpfiles.rules = [
    "d %h/.mozilla/native-messaging-hosts 0755 - - -"
  ];

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
