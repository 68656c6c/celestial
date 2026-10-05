{ ... }:

{
  services = {
    userborn.enable = true;
    tlp.enable = true;
    thermald.enable = true;
    xserver = {
      enable = true;
      desktopManager.lxqt.enable = true;
    };
  };
}
