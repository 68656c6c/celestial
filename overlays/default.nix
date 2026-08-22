{ unstable, system }:
final: prev:
let
  unstablepkgs = unstable.legacyPackages.${system};
in
{
  hyprland = unstablepkgs.hyprland;
  hyprland-plugins = unstablepkgs.hyprland-plugins;
  hyprpaper = unstablepkgs.hyprpaper;
  hypridle = unstablepkgs.hypridle;
  hyprlock = unstablepkgs.hyprlock;
  hyprpicker = unstablepkgs.hyprpicker;
  hyprutils = unstablepkgs.hyprutils;
  hyprlang = unstablepkgs.hyprlang;
  hyprcursor = unstablepkgs.hyprcursor;
  xdg-desktop-portal-hyprland = unstablepkgs.xdg-desktop-portal-hyprland;
}
