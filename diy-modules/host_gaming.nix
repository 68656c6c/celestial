{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.host.gaming;
in

{
  options.host.gaming.enable = lib.mkEnableOption "the game launchers: Steam with Millennium, Heroic, Bottles, DOSBox-X and the 32-bit graphics and audio libraries they need";

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      package = pkgs.millennium-steam;
      extest.enable = true; # steam input in wayland
    };

    environment.systemPackages = with pkgs; [
      heroic
      bottles
      dosbox-x
    ];

    services.pipewire.alsa.support32Bit = true;
  };
}
