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
  host.laptop.enable = true;

  boot.loader.timeout = 0;

  home-manager.startAsUserService = true;

  system.nixos-init.enable = true;
  system.etc.overlay.enable = true;

  sops.secrets.artesia-password = {
    sopsFile = ../../../secrets/secrets.yaml;
    neededForUsers = true;
  };

  users.users.artesia.hashedPasswordFile = config.sops.secrets.artesia-password.path;

  home-manager.users.artesia = {
    services.arrpc.enable = lib.mkForce false;
    programs.ghostty.systemd.enable = lib.mkForce false;
    programs.foot = {
      enable = true;
      settings = {
        main.font = "JetBrainsMono Nerd Font:size=12";
        colors-dark = {
          background = "000000";
          foreground = "ffe4e1";
        };
      };
    };
    wayland.windowManager.sway = {
      xwayland = false;
      config = {
        terminal = lib.mkForce "foot";
        keybindings."Mod4+q" = lib.mkForce "exec foot";
      };
    };
    systemd.user.services = {
      attic-watch-store.Install.WantedBy = lib.mkForce [ ];
      flameshot.Install.WantedBy = lib.mkForce [ ];
    };
  };

  fileSystems."/boot".options = [
    "noauto"
    "x-systemd.automount"
  ];
}
