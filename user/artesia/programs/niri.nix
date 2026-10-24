{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  cursorSize = toString osConfig.host.cursor.size;

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

  outputs = lib.concatMapStringsSep "\n" (m: ''
    output "${m.output}" {
      mode "${resolution m}${lib.optionalString (m.refresh != null) "@${fmtRefresh m.refresh}"}"
      ${lib.optionalString (m.x != null) "position x=${toString m.x} y=${toString m.y}"}
      scale ${builtins.toJSON m.scale}
    }
  '') osConfig.host.monitors;

  workspaceBinds = lib.concatMapStrings (
    i:
    let
      key = toString (lib.mod i 10);
    in
    ''
      Mod+${key} { focus-workspace ${toString i}; }
      Mod+Shift+${key} { move-window-to-workspace ${toString i}; }
    ''
  ) (lib.range 1 10);

  bitwardenRule = app: ''
    window-rule {
      match app-id="^${app}$" title=r#"^Extension: \(Bitwarden Password Manager\) - Bitwarden"#
      open-floating true
    }
  '';
in

lib.mkIf osConfig.programs.niri.enable {
  xdg.configFile."niri/config.kdl".text = ''
    spawn-at-startup "noctalia"
    spawn-at-startup "${pkgs.pantheon.pantheon-agent-polkit}/libexec/policykit-1-pantheon/io.elementary.desktop.agent-polkit"

    hotkey-overlay {
      skip-at-startup
    }

    prefer-no-csd

    environment {
      NIXOS_OZONE_WL "1"
      QT_QPA_PLATFORM "wayland"
      QT_QPA_PLATFORMTHEME "qt6ct"
    }

    cursor {
      xcursor-theme "${config.home.pointerCursor.name}"
      xcursor-size ${cursorSize}
    }

    input {
      keyboard {
        xkb {
          layout "us"
        }
      }
      touchpad {
        tap
      }
      focus-follows-mouse
    }

    ${outputs}

    layout {
      gaps 5
      center-focused-column "never"
      default-column-width { proportion 0.5; }

      preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
      }

      focus-ring {
        off
      }

      shadow {
        on
        softness 30
        spread 5
        offset x=0 y=5
        color "#0007"
      }
    }

    window-rule {
      geometry-corner-radius 20
      clip-to-geometry true
    }

    // flameshot opens its capture overlay as a fullscreen toplevel, which niri
    // would tile into a column. Float it over the whole screen instead, without
    // the rounded corners and shadow every other window gets. The pinned
    // screenshots have the title "flameshot-pin" and keep the defaults.
    window-rule {
      match app-id=r#"^flameshot$"# title=r#"^flameshot$"#
      open-floating true
      open-fullscreen false
      default-floating-position x=0 y=0
      geometry-corner-radius 0
      clip-to-geometry false
      shadow {
        off
      }
    }

    ${bitwardenRule "zen"}
    ${bitwardenRule "helium"}

    window-rule {
      match app-id=r#"^dev\.noctalia\.Noctalia$"#
      open-floating true
      default-column-width { fixed 1080; }
      default-window-height { fixed 920; }
    }

    binds {
      Mod+Q { spawn "ghostty" "+new-window"; }
      Mod+E { spawn "dolphin"; }
      Mod+C { close-window; }
      Mod+M { quit skip-confirmation=true; }
      Mod+V { toggle-window-floating; }
      Mod+F { maximize-column; }
      Mod+Shift+F { fullscreen-window; }
      Mod+R { switch-preset-column-width; }
      Mod+Comma { consume-or-expel-window-left; }
      Mod+Period { consume-or-expel-window-right; }
      Mod+O { toggle-overview; }
      Mod+Shift+Slash { show-hotkey-overlay; }

      Mod+Space { spawn "noctalia" "msg" "panel-toggle" "launcher"; }
      Mod+L { spawn "noctalia" "msg" "session" "lock"; }
      Print { spawn "flameshot" "gui"; }

      Mod+Left { focus-column-or-monitor-left; }
      Mod+Right { focus-column-or-monitor-right; }
      Mod+Up { focus-window-or-monitor-up; }
      Mod+Down { focus-window-or-monitor-down; }

      Mod+Shift+Left { move-column-left-or-to-monitor-left; }
      Mod+Shift+Right { move-column-right-or-to-monitor-right; }
      Mod+Shift+Up { move-window-up; }
      Mod+Shift+Down { move-window-down; }

    ${workspaceBinds}

      Mod+WheelScrollDown cooldown-ms=150 { focus-workspace-down; }
      Mod+WheelScrollUp cooldown-ms=150 { focus-workspace-up; }

      XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "-l" "1" "@DEFAULT_AUDIO_SINK@" "5%+"; }
      XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
      XF86AudioMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
      XF86AudioMicMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
      XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "-e4" "-n2" "set" "5%+"; }
      XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "-e4" "-n2" "set" "5%-"; }

      XF86AudioNext allow-when-locked=true repeat=false { spawn "playerctl" "next"; }
      XF86AudioPause allow-when-locked=true repeat=false { spawn "playerctl" "play-pause"; }
      XF86AudioPlay allow-when-locked=true repeat=false { spawn "playerctl" "play-pause"; }
      XF86AudioPrev allow-when-locked=true repeat=false { spawn "playerctl" "previous"; }
    }

    include optional=true "noctalia.kdl"
  '';
}
