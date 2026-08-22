{ ... }:

{
  xdg.configFile."niri/config.kdl".text = ''
    spawn-at-startup "noctalia"

    hotkey-overlay {
      skip-at-startup
    }
  '';
}
