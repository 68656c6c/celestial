{
  config,
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

  sops = {
    age.keyFile = lib.mkForce "/var/lib/sops-nix/key";
    secrets.artesia-password = {
      sopsFile = ../../../secrets/secrets.yaml;
      neededForUsers = true;
    };
  };

  users.users.artesia.hashedPasswordFile = config.sops.secrets.artesia-password.path;

  systemd.services.nix-gc.unitConfig.ConditionACPower = true;
  systemd.services.nix-optimise.unitConfig.ConditionACPower = true;

  home-manager.users.artesia = {
    services.arrpc.enable = lib.mkForce false;
    programs.fuzzel = {
      enable = true;
      settings.colors = {
        background = "000000ee";
        text = "ffe4e1ff";
        prompt = "ff5a36ff";
        input = "ffe4e1ff";
        match = "ff5a36ff";
        selection = "c8102eff";
        selection-text = "ffe4e1ff";
        selection-match = "ffb347ff";
        border = "e0303aff";
      };
    };
    systemd.user.services = {
      attic-watch-store.Install.WantedBy = lib.mkForce [ ];
      flameshot.Install.WantedBy = lib.mkForce [ ];
      tailscale-systray.Install.WantedBy = lib.mkForce [ ];
    };
  };

  fileSystems."/boot".options = [
    "noauto"
    "x-systemd.automount"
  ];
}
