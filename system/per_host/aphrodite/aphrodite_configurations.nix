{
  ...
}:

{
  networking.hostName = "aphrodite";
  host.dmi = [ "HP EliteBook x360 830 G6" ];
  # Disk in LUKS, unlocked by the TPM once Secure Boot is on (scripts/secure-host.sh)
  host.disk.encrypt = true;
  host.secureboot.enable = true;
  host.gpu = "intel";
  host.fastboot.enable = true;
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

  host.cursor.size = 32;
  host.laptop.enable = true;

  # Release this machine was first installed with. Leave it alone.
  system.stateVersion = "25.05";
  home-manager.users.artesia.home.stateVersion = "25.05";
}
