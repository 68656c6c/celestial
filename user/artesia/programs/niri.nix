{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  cursorSize = toString osConfig.host.cursor.size;

  inherit (import ../lib/monitors.nix { inherit lib; }) fmtRefresh resolution;

  outputs = lib.concatMapStringsSep "\n" (m: ''
    output "${m.output}" {
      mode "${resolution m}${lib.optionalString (m.refresh != null) "@${fmtRefresh m.refresh}"}"
      ${lib.optionalString (m.x != null) "position x=${toString m.x} y=${toString m.y}"}
      scale ${builtins.toJSON m.scale}
    }
  '') osConfig.host.monitors;

  pangolinMenuX = if builtins.length osConfig.host.monitors > 1 then "-233" else "387";

  workspaceBinds = lib.concatMap (
    i:
    let
      n = toString i;
      key = toString (lib.mod i 10);
    in
    [
      (
        {
          key = "Mod+${key}";
          action = "focus-workspace ${n}";
        }
        // lib.optionalAttrs (i == 1) { title = "Workspace 1 to 10, on keys 1 to 0"; }
      )
      (
        {
          key = "Mod+Shift+${key}";
          action = "move-window-to-workspace ${n}";
        }
        // lib.optionalAttrs (i == 1) { title = "Move window to workspace 1 to 10"; }
      )
    ]
  ) (lib.range 1 10);

  mediaKey = key: title: action: {
    inherit key title action;
    props = "allow-when-locked=true";
    overlay = false;
  };

  playerKey =
    key: title: action:
    mediaKey key title action // { props = "allow-when-locked=true repeat=false"; };

  # Every bind is written here once. niri's config, its hotkey overlay
  # (Mod+Shift+Slash) and the searchable list in the noctalia launcher
  # (Mod+Slash) are generated from this table. A bind without a title is
  # listed nowhere; `overlay = false` keeps one out of niri's overlay, which
  # is a single column that does not scroll.
  bindGroups = [
    {
      group = "Applications";
      binds = [
        {
          key = "Mod+Q";
          title = "Terminal";
          action = ''spawn "ghostty" "+new-window"'';
        }
        {
          key = "Mod+E";
          title = "File manager";
          action = ''spawn "dolphin"'';
        }
        {
          key = "Mod+Space";
          title = "Application launcher";
          action = ''spawn "noctalia" "msg" "panel-toggle" "launcher"'';
        }
        {
          key = "Mod+Slash";
          title = "Search hotkeys";
          action = ''spawn "noctalia" "msg" "panel-toggle" "launcher" "/keys"'';
        }
        {
          key = "Mod+Shift+Slash";
          title = "Hotkey overlay";
          action = "show-hotkey-overlay";
        }
      ];
    }
    {
      group = "Windows";
      binds = [
        {
          key = "Mod+C";
          title = "Close window";
          action = "close-window";
        }
        {
          key = "Mod+V";
          title = "Float or tile window";
          action = "toggle-window-floating";
        }
        {
          key = "Mod+F";
          title = "Maximise column";
          action = "maximize-column";
        }
        {
          key = "Mod+Shift+F";
          title = "Fullscreen window";
          action = "fullscreen-window";
        }
        {
          key = "Mod+R";
          title = "Cycle column width: a third, half, two thirds";
          action = "switch-preset-column-width";
        }
        {
          key = "Mod+Comma";
          title = "Move window into or out of the column on the left";
          action = "consume-or-expel-window-left";
        }
        {
          key = "Mod+Period";
          title = "Move window into or out of the column on the right";
          action = "consume-or-expel-window-right";
        }
        {
          key = "Mod+P";
          title = "Picture-in-picture: pin window to the corner, or put it back";
          action = ''spawn "niri-pip"'';
        }
        {
          key = "Mod+O";
          title = "Overview";
          action = "toggle-overview";
        }
      ];
    }
    {
      group = "Focus and move";
      binds = [
        {
          key = "Mod+Left";
          title = "Focus column or monitor to the left";
          action = "focus-column-or-monitor-left";
        }
        {
          key = "Mod+Right";
          title = "Focus column or monitor to the right";
          action = "focus-column-or-monitor-right";
        }
        {
          key = "Mod+Up";
          title = "Focus window or monitor above";
          action = "focus-window-or-monitor-up";
        }
        {
          key = "Mod+Down";
          title = "Focus window or monitor below";
          action = "focus-window-or-monitor-down";
        }
        {
          key = "Mod+Shift+Left";
          title = "Move column left, or to the monitor on the left";
          action = "move-column-left-or-to-monitor-left";
        }
        {
          key = "Mod+Shift+Right";
          title = "Move column right, or to the monitor on the right";
          action = "move-column-right-or-to-monitor-right";
        }
        {
          key = "Mod+Shift+Up";
          title = "Move window up in its column";
          action = "move-window-up";
        }
        {
          key = "Mod+Shift+Down";
          title = "Move window down in its column";
          action = "move-window-down";
        }
      ];
    }
    {
      group = "Workspaces";
      binds = workspaceBinds ++ [
        {
          key = "Mod+WheelScrollDown";
          title = "Next workspace";
          action = "focus-workspace-down";
          props = "cooldown-ms=150";
        }
        {
          key = "Mod+WheelScrollUp";
          title = "Previous workspace";
          action = "focus-workspace-up";
          props = "cooldown-ms=150";
        }
      ];
    }
    {
      group = "Screen and session";
      binds = [
        {
          key = "Print";
          title = "Screenshot";
          action = "screenshot";
        }
        {
          key = "Mod+Shift+P";
          title = "Screenshot";
          action = "screenshot";
        }
        {
          key = "Shift+Print";
          title = "Screenshot a region and annotate it";
          action = ''spawn "niri-annotate"'';
        }
        {
          key = "Mod+L";
          title = "Lock the screen";
          action = ''spawn "noctalia" "msg" "session" "lock"'';
        }
        {
          key = "Mod+M";
          title = "Quit niri";
          action = "quit";
        }
      ];
    }
    {
      group = "Media keys";
      binds = [
        (mediaKey "XF86AudioRaiseVolume" "Volume up"
          ''spawn "wpctl" "set-volume" "-l" "1" "@DEFAULT_AUDIO_SINK@" "5%+"''
        )
        (mediaKey "XF86AudioLowerVolume" "Volume down"
          ''spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"''
        )
        (mediaKey "XF86AudioMute" "Mute" ''spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"'')
        (mediaKey "XF86AudioMicMute" "Mute the microphone"
          ''spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"''
        )
        (mediaKey "XF86MonBrightnessUp" "Brightness up" ''spawn "brightnessctl" "-e4" "-n2" "set" "5%+"'')
        (mediaKey "XF86MonBrightnessDown" "Brightness down"
          ''spawn "brightnessctl" "-e4" "-n2" "set" "5%-"''
        )
        (playerKey "XF86AudioNext" "Next track" ''spawn "playerctl" "next"'')
        (playerKey "XF86AudioPause" "Play or pause" ''spawn "playerctl" "play-pause"'')
        (playerKey "XF86AudioPlay" "Play or pause" ''spawn "playerctl" "play-pause"'')
        (playerKey "XF86AudioPrev" "Previous track" ''spawn "playerctl" "previous"'')
      ];
    }
  ];

  bindLine =
    b:
    lib.concatStringsSep " " (
      [ b.key ]
      ++ lib.optional (b ? props) b.props
      ++ lib.optional (b ? title && b.overlay or true) "hotkey-overlay-title=${builtins.toJSON b.title}"
      ++ [ "{ ${b.action}; }" ]
    );

  binds = lib.concatMapStringsSep "\n\n" (
    g: lib.concatMapStringsSep "\n" (line: "  ${line}") ([ "// ${g.group}" ] ++ map bindLine g.binds)
  ) bindGroups;

  hotkeys = pkgs.writeText "niri-hotkeys.tsv" (
    lib.concatMapStrings (
      g:
      lib.concatMapStrings (b: "${b.title}\t${b.key} · ${g.group}\n") (lib.filter (b: b ? title) g.binds)
    ) bindGroups
  );

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
        --output-filename "${config.xdg.userDirs.pictures}/screenshots/%Y%m%d-%H%M%S.png"
    '';
  };

  # Mod+P: picture-in-picture mode for the focused window. Tiled -> a 960x540
  # float in the bottom-right corner that follows the active workspace (the
  # niri-float-sticky daemon moves it on every workspace switch). Floating ->
  # back into the tiling. A window on another workspace only gets a frame
  # callback about once a second, so a film streamed to Discord from a hidden
  # workspace would arrive at 1 fps; keeping it visible keeps the full rate.
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
        niri-float-sticky -ipc unset_sticky || true
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
    // Nothing sticks on its own, only what Mod+P marks. No -app-id or -title
    // filter: the daemon only ever moves windows that pass it, a manual mark
    // on any other window is silently ignored.
    spawn-at-startup "niri-float-sticky" "-disable-auto-stick"
    spawn-at-startup "niri-autofloat"

    hotkey-overlay {
      skip-at-startup
      hide-not-bound
    }

    screenshot-path "${config.xdg.userDirs.pictures}/screenshots/%Y%m%d-%H%M%S.png"

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

    // Pangolin's windows float instead of taking a column.
    window-rule {
      match app-id="^Pangolin-client$"
      open-floating true
    }

    // Its tray menu is a 946x644 window, transparent but for the menu in a
    // top corner: the right one on a single screen, the left one with
    // several. Put that menu above the tray, without a ring around the rest.
    window-rule {
      match app-id="^Pangolin-client$" title="^pangolin-client$"
      default-floating-position x=${pangolinMenuX} y=-233 relative-to="bottom-right"
      focus-ring {
        off
      }
      border {
        off
      }
      shadow {
        off
      }
    }

    // Steam's notification toasts are small floating windows, which would
    // open in the middle of the screen and take the focus.
    window-rule {
      match app-id="^steam$" title=r#"^notificationtoasts_\d+_desktop$"#
      default-floating-position x=10 y=10 relative-to="bottom-right"
      open-focused false
    }

    binds {
    ${binds}
    }

    include optional=true "noctalia.kdl"
  '';

  xdg.configFile."noctalia/hotkeys.toml" = lib.mkIf osConfig.programs.noctalia.enable {
    source = (pkgs.formats.toml { }).generate "noctalia-hotkeys.toml" {
      shell.launcher.dmenu.entry.keys = {
        command = "${pkgs.coreutils}/bin/cat ${hotkeys}";
        # Without an exec, enter copies the row to the clipboard.
        exec = "true";
        glyph = "keyboard";
        label = "Hotkeys";
        prefix = "keys";
      };
    };
  };
}
