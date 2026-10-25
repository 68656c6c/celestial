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
      width = 1920;
      height = 1080;
      scale = 1.25;
    }
  ];

  host.cursor.size = 28;
  host.laptop.enable = true;
  host.fastboot.enable = true;

  home-manager.startAsUserService = true;

  home-manager.users.artesia = {
    home.stateVersion = "25.05";
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

  # Release this machine was first installed with. Leave it alone.
  system.stateVersion = "25.05";
}
