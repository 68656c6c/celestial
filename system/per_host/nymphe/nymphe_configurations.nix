{ ... }:

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
  # lisgd reads the touchscreen next to sway
  users.users.artesia.extraGroups = [ "input" ];

  home-manager.users.artesia =
    { lib, pkgs, ... }:
    let
      # Touchscreen gestures for tablet mode. sway only binds touchpad gestures,
      # so lisgd reads the touch device itself and runs a sway command per
      # stroke. Edge strokes only, so apps keep their own swipes. Format:
      # fingers, direction (UD = top to bottom), start edge, distance, on release.
      touchGestures = pkgs.writeShellApplication {
        name = "touch-gestures";
        runtimeInputs = [
          pkgs.lisgd
          pkgs.libinput
        ];
        text = ''
          dev="$(libinput list-devices | awk '/^Kernel:/ { k = $2 } /^Capabilities:.*touch/ { print k; exit }')"
          [ -n "$dev" ] || { echo "no touchscreen found" >&2; exit 1; }
          exec lisgd -d "$dev" \
            -g "1,UD,T,*,R,swaymsg kill" \
            -g "1,RL,R,*,R,swaymsg workspace next" \
            -g "1,LR,L,*,R,swaymsg workspace prev" \
            -g "2,RL,R,*,R,swaymsg move container to workspace next" \
            -g "2,LR,L,*,R,swaymsg move container to workspace prev" \
            -g "2,UD,T,*,R,swaymsg floating toggle" \
            -g "2,DU,B,*,R,swaymsg fullscreen toggle" \
            -g "1,DU,B,*,R,busctl call --user sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true"
        '';
      };
    in
    {
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
      home.packages = [
        pkgs.squeekboard
        touchGestures
      ];
      dconf.settings = {
        # On-screen layout only; the physical keyboard stays on sway's xkb setting.
        "org/gnome/desktop/input-sources".sources = [
          (lib.hm.gvariant.mkTuple [
            "xkb"
            "us+dvorak"
          ])
        ];
        # Panel height multiplier, keys stretch with it (1.0 is the default, 2.0 the cap)
        "sm/puri/Squeekboard" = {
          scale-in-horizontal-screen-orientation = 1.3;
          scale-in-vertical-screen-orientation = 1.2;
        };
      };
      wayland.windowManager.sway = {
        xwayland = false;
        config = {
          terminal = lib.mkForce "foot";
          keybindings."Mod4+q" = lib.mkForce "exec foot";
          startup = [
            { command = "squeekboard"; }
            { command = "touch-gestures"; }
          ];
        };
      };
      systemd.user.services = {
        flameshot.Install.WantedBy = lib.mkForce [ ];
      };
    };

  # Release this machine was first installed with. Leave it alone.
  system.stateVersion = "25.05";
}
