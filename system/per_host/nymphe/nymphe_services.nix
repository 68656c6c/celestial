{ ... }:

{
  services = {
    userborn.enable = true;
    xserver = {
      enable = true;
      desktopManager.lxqt.enable = true;
    };
  };
}
