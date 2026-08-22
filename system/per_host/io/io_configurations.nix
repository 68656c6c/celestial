{
  config,
  pkgs,
  lib,
  ...
}:

{
  networking.hostName = "io";

  lab_local.vpn = {
    enable = true;
    updateDns = true;
  };

  boot.loader.systemd-boot.extraEntries = {
    "Windows11.conf" = ''
      title Windows 11 Pro
      efi /EFI/Microsoft/Boot/bootmgfw.efi
    '';
  };
}
