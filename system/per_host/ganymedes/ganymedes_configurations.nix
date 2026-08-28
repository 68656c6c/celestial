{
  config,
  pkgs,
  ...
}:

{
  networking.hostName = "ganymedes";
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];

  host.monitors = [
    {
      output = "eDP-1";
      mode = "1920x1080";
      scale = 1.0;
    }
  ];

  vpn.lab_local = {
    enable = true;
    updateDns = true;
  };

  vpn.tailscale.enable = true;

  security = {
    tpm2.enable = false;
  };
}
