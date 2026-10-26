{ lib, osConfig, ... }:

# sway only: under niri the portal screenshot path handles a single output and
# the overlay covers one monitor, so niri uses its own screenshot UI instead.
lib.mkIf osConfig.programs.sway.enable {
  services.flameshot = {
    enable = true;
    settings = {
      General = {
        showStartupLaunchMessage = false;
        startupLaunch = true;
      };
    };
  };
}
