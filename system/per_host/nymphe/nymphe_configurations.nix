{
  config,
  pkgs,
  ...
}:

{
  networking.hostName = "nymphe";

  lab_local.vpn = {
    enable = true;
    updateDns = true;
  };
}
