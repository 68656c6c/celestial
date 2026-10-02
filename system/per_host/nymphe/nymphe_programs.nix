{ ... }:

{
  programs = {
    noctalia = {
      enable = true;
      recommendedServices.enable = true;
    };
    sway = {
      enable = true;
      wrapperFeatures.gtk = true;
      extraSessionCommands = ''
        export NIXOS_OZONE_WL=1
        export QT_QPA_PLATFORM=wayland
        export QT_QPA_PLATFORMTHEME=qt6ct
      '';
    };
  };
}
