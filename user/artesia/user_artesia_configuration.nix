{
  config,
  pkgs,
  lib,
  diy,
  osConfig,
  ...
}:

let
  cursorSize = builtins.toString osConfig.host.cursor.size;
in

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

  services.arrpc.enable = true;
  services.arrpc.systemdTarget = "graphical.target";

  systemd.user.sessionVariables = {
    NIXOS_OZONE_WL = 1;
    QT_QPA_PLATFORMTHEME = "gtk3";
    GTK_THEME = "adw-gtk3-dark";
    QT_STYLE_OVERRIDE = "kvantum-dark";
    KVANTUM_THEME = "Gruvbox-Dark";
    NH_OS_FLAKE = "/home/artesia/.dotfiles";
    XCURSOR_SIZE = cursorSize;
  };

  #wayland.windowManager.hyprland = {
  #  enable = true;
  #  package = null;
  #  portalPackage = null;
  #};

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

  xdg.configFile."lxqt/lxqt-config-appearance.conf".text = ''
    [General]
    theme=adw-gtk3-dark
    icon_theme=MoreWaita
  '';

  xdg.configFile."kdeglobals".text = ''
    [General]
    Name=Breeze
    shadeSortColumn=true

    [ColorEffect:Disabled]
    Color=56,56,56
    ColorAmount=0
    ColorEffect=0
    ContrastAmount=0.65
    ContrastEffect=1
    IntensityAmount=0.1
    IntensityEffect=2

    [ColorEffects:Disabled]
    Color=56,56,56
    ColorAmount=0
    ColorEffect=0
    ContrastAmount=0.65
    ContrastEffect=1
    IntensityAmount=0.1
    IntensityEffect=2

    [Colors:Button]
    BackgroundNormal=49,54,61
    BackgroundAlternate=49,54,61
    DecorationFocus=61,174,233
    DecorationHover=61,174,233
    ForegroundActive=61,174,233
    ForegroundInactive=189,195,201
    ForegroundLink=29,153,215
    ForegroundNegative=218,76,76
    ForegroundNeutral=246,189,65
    ForegroundNormal=239,240,242
    ForegroundPositive=153,220,108
    ForegroundVisited=145,129,190

    [Colors:Selection]
    BackgroundNormal=61,174,233
    BackgroundAlternate=61,174,233
    DecorationFocus=61,174,233
    DecorationHover=61,174,233
    ForegroundActive=239,240,242
    ForegroundInactive=239,240,242
    ForegroundLink=239,240,242
    ForegroundNegative=239,240,242
    ForegroundNeutral=239,240,242
    ForegroundNormal=239,240,242
    ForegroundPositive=239,240,242
    ForegroundVisited=239,240,242

    [Colors:Tooltip]
    BackgroundNormal=49,54,61
    BackgroundAlternate=49,54,61
    DecorationFocus=61,174,233
    DecorationHover=61,174,233
    ForegroundActive=61,174,233
    ForegroundInactive=189,195,201
    ForegroundLink=29,153,215
    ForegroundNegative=218,76,76
    ForegroundNeutral=246,189,65
    ForegroundNormal=239,240,242
    ForegroundPositive=153,220,108
    ForegroundVisited=145,129,190

    [Colors:View]
    BackgroundNormal=35,39,45
    BackgroundAlternate=42,46,52
    DecorationFocus=61,174,233
    DecorationHover=61,174,233
    ForegroundActive=61,174,233
    ForegroundInactive=189,195,201
    ForegroundLink=29,153,215
    ForegroundNegative=218,76,76
    ForegroundNeutral=246,189,65
    ForegroundNormal=239,240,242
    ForegroundPositive=153,220,108
    ForegroundVisited=145,129,190

    [Colors:Window]
    BackgroundNormal=35,39,45
    BackgroundAlternate=42,46,52
    DecorationFocus=61,174,233
    DecorationHover=61,174,233
    ForegroundActive=61,174,233
    ForegroundInactive=189,195,201
    ForegroundLink=29,153,215
    ForegroundNegative=218,76,76
    ForegroundNeutral=246,189,65
    ForegroundNormal=239,240,242
    ForegroundPositive=153,220,108
    ForegroundVisited=145,129,190

    [WM]
    activeBackground=35,39,45
    activeBlend=35,39,45
    activeForeground=239,240,242
    inactiveBackground=35,39,45
    inactiveBlend=35,39,45
    inactiveForeground=189,195,201
  '';

  home.stateVersion = "25.05"; # Have you read da comment?
}
