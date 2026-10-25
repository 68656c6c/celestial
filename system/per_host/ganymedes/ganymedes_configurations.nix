{
  pkgs,
  ...
}:

{
  networking.hostName = "ganymedes";
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

  # ALC255 pin re-task. The headphone jack (0x21) reports "plugged" with
  # nothing in it, so PipeWire marks the speakers (0x14) unavailable. Turn
  # off jack detection on 0x21: both ports become selectable, no auto switch.
  # 0x17 is the mono amp driving the subwoofer, left unconfigured by the BIOS.
  # patch= is one entry per controller and the NVIDIA HDMI one probes first,
  # so list it twice; the [codec] line keeps it to the Realtek.
  boot.extraModprobeConfig = "options snd-hda-intel patch=hda-jack-retask.fw,hda-jack-retask.fw";
  hardware.firmware = [
    (pkgs.writeTextDir "lib/firmware/hda-jack-retask.fw" ''
      [codec]
      0x10ec0255 0x1025105b 0
      [pincfg]
      0x21 0x03211120
      0x17 0x90170111
    '')
  ];

  security = {
    tpm2.enable = false;
  };

  # Release this machine was first installed with. Leave it alone.
  system.stateVersion = "25.05";
  home-manager.users.artesia.home.stateVersion = "25.05";
}
