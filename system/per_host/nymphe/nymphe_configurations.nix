{
  config,
  pkgs,
  ...
}:

{
  networking.hostName = "nymphe";
  host.cursor.size = 32;
  lab_local.vpn = {
    enable = true;
    updateDns = true;
  };
}
