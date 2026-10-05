{
  lib,
  ...
}:

{
  networking.hostName = "nymphe";
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];

  host.monitors = [
    {
      output = "eDP-1";
      mode = "1920x1080";
      scale = 1.25;
    }
  ];

  host.cursor.size = 28;
  vpn.lab_local = {
    enable = true;
    updateDns = true;
  };

  vpn.tailscale.enable = true;

  boot.loader.timeout = 0;

  home-manager.startAsUserService = true;

  system.nixos-init.enable = true;
  system.etc.overlay.enable = true;

  sops.useSystemdActivation = true;

  systemd.services.nix-gc.unitConfig.ConditionACPower = true;
  systemd.services.nix-optimise.unitConfig.ConditionACPower = true;

  home-manager.users.artesia = {
    services.arrpc.enable = lib.mkForce false;
    systemd.user.services.attic-watch-store.Install.WantedBy = lib.mkForce [ ];
  };

  fileSystems."/boot".options = [
    "noauto"
    "x-systemd.automount"
  ];
}
