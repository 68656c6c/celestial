{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  mod = "Mod4";

  # 143.973 -> "143.973", 60.0 -> "60.000"
  fmtRefresh =
    r:
    let
      whole = builtins.floor r;
      milli = builtins.floor ((r - whole) * 1000 + 0.5);
    in
    if milli == 1000 then
      "${toString (whole + 1)}.000"
    else
      "${toString whole}.${lib.fixedWidthNumber 3 milli}";

  resolution = m: "${toString m.width}x${toString m.height}";
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
      defaultWorkspace = "workspace number 1";

      output =
        lib.listToAttrs (
          map (m: {
            name = m.output;
            value = {
              scale = toString m.scale;
              mode = "${resolution m}${lib.optionalString (m.refresh != null) "@${fmtRefresh m.refresh}Hz"}";
            }
            // lib.optionalAttrs (m.x != null) { position = "${toString m.x} ${toString m.y}"; };
          }) osConfig.host.monitors
        )
        // {
          "*".bg = "${config.home.homeDirectory}/.dotfiles/wallpapers/1721870130513827.png fill";
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

      bars = [ ];

      startup = [
        { command = "nm-applet --indicator"; }
        { command = lib.getExe pkgs.mako; }
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
        "Print" = "exec flameshot gui";

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
      # Bitwarden popouts: Firefox-based browsers prefix extension windows, Chromium-based ones carry the bare page title
      for_window [app_id="^zen$" title="^Extension: \(Bitwarden Password Manager\)"] floating enable
      for_window [app_id="^helium$" title="^Bitwarden( Password Manager)?$"] floating enable
      # flameshot's capture overlay must float at the origin to cover the screen instead of tiling (flameshot docs)
      for_window [app_id="flameshot"] border pixel 0, floating enable, fullscreen disable, move absolute position 0 0
    '';
  };

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

  systemd.user.services.waybar = {
    Unit.Before = [ "tray.target" ];
    Service = {
      Type = "dbus";
      BusName = "org.kde.StatusNotifierWatcher";
    };
    Install.WantedBy = lib.mkForce [ "sway-session.target" ];
  };

  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      targets = [ "sway-session.target" ];
    };
    settings.main = {
      layer = "top";
      position = "bottom";
      height = 28;
      modules-left = [
        "custom/launcher"
        "sway/workspaces"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "tray"
        "wireplumber"
        "backlight"
        "custom/nightlight"
        "power-profiles-daemon"
        "battery"
      ];

      "custom/launcher" = {
        format = "󰀻";
        tooltip = false;
        on-click = "fuzzel";
      };

      clock = {
        format = "{:%a %d %b  %H:%M}";
        tooltip-format = "<tt>{calendar}</tt>";
      };

      tray.spacing = 8;

      wireplumber = {
        format = "{icon} {volume}%";
        format-muted = "󰝟 muted";
        format-icons = [
          "󰕿"
          "󰖀"
          "󰕾"
        ];
        on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        on-click-right = "pwvucontrol";
      };

      backlight = {
        format = "{icon} {percent}%";
        format-icons = [
          "󰃞"
          "󰃟"
          "󰃠"
        ];
        on-scroll-up = "brightnessctl -e4 -n2 set 5%+";
        on-scroll-down = "brightnessctl -e4 -n2 set 5%-";
      };

      "custom/nightlight" = {
        format = "󰖔 {}";
        tooltip = false;
        exec = "${lib.getExe pkgs.wl-gammarelay-rs} watch {t}K";
        on-click = "busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Temperature q $([ \"$(busctl --user get-property rs.wl-gammarelay / rs.wl.gammarelay Temperature)\" = 'q 6500' ] && echo 3100 || echo 6500)";
        on-scroll-up = "busctl --user -- call rs.wl-gammarelay / rs.wl.gammarelay UpdateTemperature n +100";
        on-scroll-down = "busctl --user -- call rs.wl-gammarelay / rs.wl.gammarelay UpdateTemperature n -100";
      };

      power-profiles-daemon = {
        format = "{icon}";
        tooltip-format = "{profile}";
        format-icons = {
          performance = "󰓅";
          balanced = "󰾅";
          power-saver = "󰾆";
        };
      };

      battery = {
        format = "{icon} {capacity}%";
        format-charging = "󰂄 {capacity}%";
        format-icons = [
          "󰁺"
          "󰁼"
          "󰁾"
          "󰂀"
          "󰁹"
        ];
        states = {
          warning = 20;
          critical = 10;
        };
      };
    };
    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        border: none;
        border-radius: 0;
        min-height: 0;
      }

      window#waybar {
        background: rgba(0, 0, 0, 0.85);
        color: #ffe4e1;
      }

      #workspaces button {
        padding: 0 8px;
        color: #ffe4e1;
      }

      #workspaces button.focused {
        background: #c8102e;
      }

      #workspaces button.urgent {
        background: #ff5a36;
      }

      #custom-launcher {
        padding: 0 12px;
        font-size: 16px;
        color: #ff5a36;
      }

      #clock,
      #tray,
      #wireplumber,
      #backlight,
      #custom-nightlight,
      #power-profiles-daemon,
      #battery {
        padding: 0 10px;
      }

      #battery.warning {
        color: #ffb347;
      }

      #battery.critical {
        color: #e0303a;
      }
    '';
  };

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
