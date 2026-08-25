{
  config,
  pkgs,
  ...
}:

{
  networking.hostName = "ganymedes";

  lab_local.vpn = {
    enable = true;
    updateDns = true;
  };

  security = {
    tpm2.enable = false;
  };
}
