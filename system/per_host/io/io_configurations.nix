{
  config,
  inputs,
  pkgs,
  ...
}:

{
  networking.hostName = "io";
  host.disk.layout = "ext4";
  host.gpu = "nvidia";
  host.fastboot.enable = true;
  boot.loader.timeout = 3; # the Windows entry must stay reachable

  # CachyOS LTS kernel (BORE, sched_ext), prebuilt by Chaotic Nyx. The nvidia
  # 580 modules are built against it locally, the cache only has the current
  # nvidia branch.
  boot.kernelPackages =
    inputs.chaotic.unrestrictedPackages.${pkgs.stdenv.hostPlatform.system}.linuxPackages_cachyos-lts;
  nix.settings = {
    substituters = [ "https://nyx-cache.chaotic.cx/" ];
    trusted-public-keys = [ "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk=" ];
  };
  # networking.nameservers = [
  #   "10.2.50.1"
  #   "10.44.4.2"
  # ];

  host.monitors = [
    {
      output = "HDMI-A-1";
      width = 1920;
      height = 1080;
      x = 0;
      y = 0;
    }
    {
      output = "DP-1";
      width = 2560;
      height = 1440;
      refresh = 143.973;
      x = 1920;
      y = 0;
    }
    {
      output = "DVI-I-1";
      width = 1920;
      height = 1200;
      x = 4480;
      y = 0;
    }
  ];

  hardware.nvidia = {
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
