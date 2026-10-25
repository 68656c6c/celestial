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

  # ALC255 pin re-task: the BIOS marks the speaker (0x1b) and subwoofer (0x17)
  # pins as jack-sensed, so they show as "not available". Make them fixed
  # internal speakers. Pin map from other Predator G9-79x/59x owners; a pin
  # that does not exist is ignored by the kernel, so a wrong map changes nothing.
  boot.extraModprobeConfig = "options snd-hda-intel patch=hda-jack-retask.fw";
  hardware.firmware = [
    (pkgs.writeTextDir "lib/firmware/hda-jack-retask.fw" ''
      [codec]
      0 0 0
      [pincfg]
      0x1b 0x90170110
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
