{
  config,
  ...
}:

{
  networking.hostName = "io";
  # networking.nameservers = [
  #   "10.2.50.1"
  #   "10.44.4.2"
  # ];

  host.monitors = [
    {
      output = "HDMI-A-1";
      mode = "1920x1080";
      position = "0x0";
      scale = 1.0;
    }
    {
      output = "DP-1";
      mode = "2560x1440@143.973";
      position = "1920x0";
      scale = 1.0;
    }
    {
      output = "DVI-I-1";
      mode = "1920x1200";
      position = "4480x0";
      scale = 1.0;
    }
  ];

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };

  # keep wayland compositors from hoarding vram on the 4gb card (niri wiki)
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
    builtins.toJSON {
      rules = [
        {
          pattern = {
            feature = "procname";
            matches = "niri";
          };
          profile = "Limit Free Buffer Pool On Wayland Compositors";
        }
      ];
      profiles = [
        {
          name = "Limit Free Buffer Pool On Wayland Compositors";
          settings = [
            {
              key = "GLVidHeapReuseRatio";
              value = 0;
            }
          ];
        }
      ];
    };

  boot.loader.systemd-boot.extraEntries = {
    "Windows11.conf" = ''
      title Windows 11 Pro
      efi /EFI/Microsoft/Boot/bootmgfw.efi
    '';
  };

  # Release this machine was first installed with. Leave it alone.
  system.stateVersion = "25.05";
  home-manager.users.artesia.home.stateVersion = "25.05";
}
