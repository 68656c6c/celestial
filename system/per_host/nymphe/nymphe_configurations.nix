{
  config,
  pkgs,
  ...
}:

{
  networking.hostName = "nymphe";
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];
  host.cursor.size = 32;
  lab_local.vpn = {
    enable = true;
    updateDns = true;
  };
}
