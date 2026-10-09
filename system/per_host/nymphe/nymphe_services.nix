{ ... }:

{
  services = {
    userborn.enable = true;
    tlp = {
      enable = true;
      pd.enable = true;
    };
    thermald.enable = true;
    gnome.gcr-ssh-agent.enable = false;
  };
}
