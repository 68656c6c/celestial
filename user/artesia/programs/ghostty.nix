{ lib, osConfig, ... }:
{
  programs.ghostty = {
    enable = true;
    systemd.enable = true;
    settings = {
      theme = lib.mkIf osConfig.programs.noctalia.enable "noctalia";
      font-size = 12;
      background-opacity = 1;
    };
  };
}
