{
  config,
  pkgs,
  ...
}:

{
  networking.hostName = "ganymedes";
  host.dmi = [ "Predator G9-791" ];
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];

  host.monitors = [
    {
      output = "eDP-1";
      width = 1920;
      height = 1080;
      scale = 1.0;
    }
  ];

  host.laptop.enable = true;
  host.fastboot.enable = true;
  host.gpu = "intel";

  # GTX 980M next to the iGPU. The desktop renders on Intel, games get the
  # NVIDIA card through `nvidia-offload <cmd>`. Maxwell cannot power down at
  # runtime under the proprietary driver, so it idles at a few watts.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    powerManagement.enable = true;
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # ALC255 pin re-task. The headphone jack (0x21) reports "plugged" with
  # nothing in it, so PipeWire marks the speakers unavailable. Turn off jack
  # detection on 0x21: both ports become selectable, no auto switch.
  # The BIOS only wires the left pair (0x14). 0x1b drives the right pair and
  # 0x17 (mono amp) the subwoofers; make them front / back / LFE of one group,
  # the hdajackretask map every G9-79x owner ended up with. Shows up as a
  # 5.1 output in PipeWire, pick that profile once.
  # patch= is one entry per controller and the NVIDIA HDMI one probes first,
  # so list it twice; the [codec] line keeps it to the Realtek.
  boot.extraModprobeConfig = "options snd-hda-intel patch=hda-jack-retask.fw,hda-jack-retask.fw";
  hardware.firmware = [
    (pkgs.writeTextDir "lib/firmware/hda-jack-retask.fw" ''
      [codec]
      0x10ec0255 0x1025105b 0
      [pincfg]
      0x21 0x03211120
      0x14 0x90170150
      0x17 0x90170151
      0x1b 0x90170152
    '')
  ];

  security = {
    tpm2.enable = false;
  };

  # Release this machine was first installed with. Leave it alone.
  system.stateVersion = "25.05";
  home-manager.users.artesia.home.stateVersion = "25.05";
}
