{
  pkgs,
  ...
}:

{
  networking.hostName = "io";
  networking.nameservers = [
    "192.168.44.2"
    "10.44.4.2"
  ];

  host.monitors = [
    {
      output = "HDMI-A-2";
      mode = "1920x1080";
      position = "0x0";
      scale = 1.0;
    }
    {
      output = "DP-2";
      mode = "2560x1440@144";
      position = "1920x0";
      scale = 1.0;
    }
    {
      output = "DP-1";
      mode = "1920x1200";
      position = "4480x0";
      scale = 1.0;
    }
  ];

  vpn.lab_local = {
    enable = false;
    updateDns = false;
  };

  vpn.tailscale.enable = false;

  hardware.graphics.enable = true;
  hardware.nvidia.modesetting.enable = true;

  boot.loader.systemd-boot.extraEntries = {
    "Windows11.conf" = ''
      title Windows 11 Pro
      efi /EFI/Microsoft/Boot/bootmgfw.efi
    '';
  };
}
