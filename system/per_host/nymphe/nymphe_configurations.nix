{
  lib,
  pkgs,
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
  # Lenovo conservation mode: 1 stops charging at 60%, 0 charges to full.
  # Off for travelling, back to 1 when the laptop lives on the charger again.
  services.tlp.settings.STOP_CHARGE_THRESH_BAT0 = 0;
  host.fastboot.enable = true;
  host.gpu = "intel";
  hardware.bluetooth.enable = true;

  home-manager.users.artesia = {
    home.stateVersion = "25.05";
    services.arrpc.enable = lib.mkForce false;
    services.blueman-applet.enable = true;
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
    # Folded over, the firmware cuts keyboard and touchpad but tells the OS
    # nothing (no tablet switch), so tablet mode is the waybar keyboard
    # button. squeekboard always runs, hidden; the button flips the GNOME
    # accessibility key it watches and it then pops up on text fields.
    # Manual show: busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true
    home.packages = [ pkgs.squeekboard ];
    wayland.windowManager.sway = {
      xwayland = false;
      config = {
        terminal = lib.mkForce "foot";
        keybindings."Mod4+q" = lib.mkForce "exec foot";
        startup = [ { command = "squeekboard"; } ];
      };
    };
    systemd.user.services = {
      flameshot.Install.WantedBy = lib.mkForce [ ];
    };
  };

  # Release this machine was first installed with. Leave it alone.
  system.stateVersion = "25.05";
}
