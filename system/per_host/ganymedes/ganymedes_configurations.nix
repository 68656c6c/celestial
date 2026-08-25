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

  lab_local.vpn = {
    enable = true;
    updateDns = true;
  };

  security = {
    tpm2.enable = false;
  };
}
