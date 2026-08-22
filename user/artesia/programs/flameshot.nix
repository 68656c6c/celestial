{ pkgs, unstable, ... }:

{
  services.flameshot = {
    enable = true;
    package = unstable.flameshot;
    settings = {
      General = {
        showStartupLaunchMessage = false;
        startupLaunch = true;
      };
    };
  };
}
