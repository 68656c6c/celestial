{ unstable, niri-float-sticky }:
final: _prev: {
  # Software not in nixpkgs, available as pkgs.diy.<name>
  diy = import ../diy-packages { pkgs = final; };
  inherit niri-float-sticky;

  # Stable release for everything, unstable for the few that need to move faster
  hyprpicker = unstable.hyprpicker;
  nushell = unstable.nushell;
  atuin = unstable.atuin;
  flameshot = unstable.flameshot;
  noctalia = unstable.noctalia;
  bitwarden-desktop = unstable.bitwarden-desktop;
  opencode = unstable.opencode;
  claude-code = unstable.claude-code;
  pangolin-cli = unstable.pangolin-cli;
}
