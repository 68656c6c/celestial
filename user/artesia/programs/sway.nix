{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  mod = "Mod4";
in

lib.mkIf osConfig.programs.sway.enable {
  wayland.windowManager.sway = {
    enable = true;
    package = null;
    checkConfig = false;

    config = {
      modifier = mod;
      terminal = "ghostty +new-window";
      menu = "fuzzel";

      output =
        lib.listToAttrs (
          map (m: {
            name = m.output;
            value = {
              scale = toString m.scale;
            }
            // lib.optionalAttrs (m.mode != "") { mode = m.mode; }
            // lib.optionalAttrs (m.position != "") {
              position = lib.replaceStrings [ "x" ] [ " " ] m.position;
            };
          }) osConfig.host.monitors
        )
        // {
          "*".bg = "/home/artesia/.dotfiles/wallpapers/1721870130513827.png fill";
        };

      input = {
        "type:keyboard".xkb_layout = "us";
        "type:touchpad".tap = "enabled";
      };

      seat."*".xcursor_theme = "${config.home.pointerCursor.name} ${toString osConfig.host.cursor.size}";

      focus.followMouse = true;
      floating.modifier = mod;

      window = {
        titlebar = false;
        border = 2;
      };

      bars = [
        {
          position = "bottom";
          statusCommand = "i3status";
        }
      ];

      startup = [
        { command = "nm-applet --indicator"; }
      ];

      keybindings = {
        "${mod}+q" = "exec ghostty +new-window";
        "${mod}+c" = "kill";
        "${mod}+m" = "exec swaymsg exit";
        "${mod}+e" = "exec dolphin";
        "${mod}+v" = "floating toggle";
        "${mod}+j" = "split toggle";
        "${mod}+f" = "fullscreen toggle";
        "${mod}+space" = "exec fuzzel";
        "${mod}+l" = "exec swaylock -f";

        "${mod}+Left" = "focus left";
        "${mod}+Right" = "focus right";
        "${mod}+Up" = "focus up";
        "${mod}+Down" = "focus down";

        "${mod}+Shift+Left" = "move left";
        "${mod}+Shift+Right" = "move right";
        "${mod}+Shift+Up" = "move up";
        "${mod}+Shift+Down" = "move down";

        "${mod}+s" = "scratchpad show";
        "${mod}+Shift+s" = "move scratchpad";

        "--whole-window ${mod}+button4" = "workspace prev";
        "--whole-window ${mod}+button5" = "workspace next";

        "--locked XF86AudioRaiseVolume" = "exec wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+";
        "--locked XF86AudioLowerVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        "--locked XF86AudioMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        "--locked XF86AudioMicMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        "--locked XF86MonBrightnessUp" = "exec brightnessctl -e4 -n2 set 5%+";
        "--locked XF86MonBrightnessDown" = "exec brightnessctl -e4 -n2 set 5%-";
        "--locked --no-repeat XF86AudioNext" = "exec playerctl next";
        "--locked --no-repeat XF86AudioPause" = "exec playerctl play-pause";
        "--locked --no-repeat XF86AudioPlay" = "exec playerctl play-pause";
        "--locked --no-repeat XF86AudioPrev" = "exec playerctl previous";
      }
      // lib.listToAttrs (
        lib.concatMap (
          i:
          let
            key = toString (lib.mod i 10);
          in
          [
            (lib.nameValuePair "${mod}+${key}" "workspace number ${toString i}")
            (lib.nameValuePair "${mod}+Shift+${key}" "move container to workspace number ${toString i}")
          ]
        ) (lib.range 1 10)
      );
    };

    extraConfig = ''
      bindgesture swipe:3:left workspace next
      bindgesture swipe:3:right workspace prev
      for_window [app_id="^(zen|helium)$" title="^Extension: \(Bitwarden Password Manager\) - Bitwarden"] floating enable
    '';
  };

  programs.i3status.enable = true;

  services.mako.enable = true;

  xdg.portal = {
    config.sway = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
    };
    extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
  };
}
