{ ... }:

{
  services = {
    userborn.enable = true;
    tlp.enable = true;
    thermald.enable = true;
    gnome.gcr-ssh-agent.enable = false;
    xserver = {
      enable = true;
      desktopManager.lxqt.enable = true;
    };
  };
}
