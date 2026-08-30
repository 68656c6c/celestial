{ ... }:

{
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
