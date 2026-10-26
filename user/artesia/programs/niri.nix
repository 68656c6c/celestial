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

  # Bitwarden popouts (unlock, passkey picker, ...) as an overlay instead of a
  # tiled column. Firefox-based browsers prefix extension windows with
  # "Extension: (name)", Chromium-based ones carry the bare page title.
  bitwardenTitle = {
    zen = "^Extension: \\(Bitwarden Password Manager\\)";
    helium = "^Bitwarden( Password Manager)?$";
  };

  bitwardenRule = app: ''
    window-rule {
      match app-id="^${app}$" title=r#"${bitwardenTitle.${app}}"#
      open-floating true
      default-floating-position x=0 y=120 relative-to="top"
    }
  '';

  # Firefox maps popup windows before it sets their title, so the rule above
  # misses them. Watch the event stream and float a Bitwarden popout the moment
  # its title shows up.
  niriAutofloat = pkgs.writeShellApplication {
    name = "niri-autofloat";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      niri msg --json event-stream | while read -r ev; do
        id="$(jq -r --arg re '${bitwardenTitle.zen}|${bitwardenTitle.helium}' '
          .WindowOpenedOrChanged.window // empty
          | select(.is_floating == false)
          | select((.app_id // "") | test("^(zen|helium)$"))
          | select((.title // "") | test($re))
          | .id' <<<"$ev")"
        [ -n "$id" ] || continue
        niri msg action toggle-window-floating --id "$id"
        niri msg action center-window --id "$id"
      done
    '';
  };

  # Mod+P: picture-in-picture mode for the focused window. Tiled -> a 960x540
  # float in the bottom-right corner that follows the active workspace (the
  # niri-float-sticky daemon moves it on every workspace switch). Floating ->
  # back into the tiling. A window on another workspace only gets a frame
  # callback about once a second, so a film streamed to Discord from a hidden
  # workspace would arrive at 1 fps; keeping it visible keeps the full rate.
  # Shift+Print: pick a region on any monitor, annotate it in satty. niri's own
  # screenshot UI (Print) covers the plain case; flameshot cannot, its portal
  # path in niri only handles a single output.
  niriAnnotate = pkgs.writeShellApplication {
    name = "niri-annotate";
    runtimeInputs = [
      pkgs.grim
      pkgs.slurp
      pkgs.satty
      pkgs.wl-clipboard
    ];
    text = ''
      region="$(slurp)" || exit 0
      grim -g "$region" - | satty --filename - --copy-command wl-copy \
        --output-filename "$HOME/Pictures/Screenshots/%Y%m%d-%H%M%S.png"
    '';
  };

  niriPip = pkgs.writeShellApplication {
    name = "niri-pip";
    runtimeInputs = [
      pkgs.jq
      pkgs.niri-float-sticky
    ];
    text = ''
      win="$(niri msg --json focused-window)"
      [ "$win" = "null" ] && exit 0
      if [ "$(jq -r .is_floating <<<"$win")" = "true" ]; then
        niri-float-sticky -ipc unset_sticky
        niri msg action toggle-window-floating
        exit 0
      fi
      out="$(niri msg --json focused-output)"
      w=960; h=540; margin=24
      x=$(( $(jq -r .logical.width <<<"$out") - w - margin ))
      y=$(( $(jq -r .logical.height <<<"$out") - h - margin ))
      niri msg action toggle-window-floating
      niri msg action set-window-width "$w"
      niri msg action set-window-height "$h"
      niri msg action move-floating-window -x "$x" -y "$y"
      niri-float-sticky -ipc set_sticky
    '';
  };
in

lib.mkIf osConfig.programs.niri.enable {
  home.packages = [
    pkgs.niri-float-sticky
    niriPip
    niriAutofloat
    niriAnnotate
  ];

  xdg.configFile."niri/config.kdl".text = ''
    spawn-at-startup "noctalia"
    // Bare mpv and browser picture-in-picture windows stick on their own;
    // everything else through Mod+P.
    spawn-at-startup "niri-float-sticky" "-app-id" "^mpv$" "-title" "^Picture-in-Picture$"
    spawn-at-startup "niri-autofloat"
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
      // niri's own backdrop, visible until noctalia has drawn the wallpaper
      background-color "#000000"
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

    ${bitwardenRule "zen"}
    ${bitwardenRule "helium"}

    // The window Discord (or anything else) is streaming gets a thin red border.
    window-rule {
      match is-window-cast-target=true
      border {
        on
        width 2
        active-color "#e53935"
        inactive-color "#e53935"
      }
    }

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
      Mod+P { spawn "niri-pip"; }
      Mod+Shift+Slash { show-hotkey-overlay; }

      Mod+Space { spawn "noctalia" "msg" "panel-toggle" "launcher"; }
      Mod+L { spawn "noctalia" "msg" "session" "lock"; }
      Print { screenshot; }
      Shift+Print { spawn "niri-annotate"; }

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
