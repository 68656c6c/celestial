{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  inherit (import ../lib/monitors.nix { inherit lib; }) fmtRefresh resolution;

  umbriel = osConfig.programs.umbriel.package;

  screenshots = "${config.xdg.userDirs.pictures}/screenshots";

  outputs = lib.concatMapStringsSep "\n" (m: ''
    [output."${m.output}"]
    mode = "${resolution m}${lib.optionalString (m.refresh != null) "@${fmtRefresh m.refresh}"}"
    ${lib.optionalString (m.x != null) "position = [${toString m.x}, ${toString m.y}]"}
    scale = ${builtins.toJSON m.scale}
  '') osConfig.host.monitors;

  pangolinMenuX = if builtins.length osConfig.host.monitors > 1 then "-233" else "387";

  workspaceBinds = lib.concatMapStrings (
    i:
    let
      key = toString (lib.mod i 10);
    in
    ''
      "Mod+${key}" = "workspace-switch ${toString i}"
      "Mod+Shift+${key}" = "window-move-to-workspace ${toString i}"
    ''
  ) (lib.range 1 10);

  # Mod+P, what niri-pip does in niri.nix. A pinned window floats above the
  # rest on every workspace of its output, so no sticky daemon is involved.
  umbrielPip = pkgs.writeShellApplication {
    name = "umbriel-pip";
    runtimeInputs = [
      umbriel
      pkgs.jq
    ];
    text = ''
      win="$(umbriel focused-window --json 2>/dev/null)" || exit 0
      umbriel msg window-toggle-pinned
      [ "$(jq -r .pinned <<<"$win")" = "true" ] && exit 0
      umbriel msg window-set-primary-extent 0.5
      umbriel msg window-set-secondary-extent 0.5
      umbriel msg window-move-to bottom_right 24 24
    '';
  };

  configText = pkgs.writeText "umbriel-config.toml" ''
    # noctalia's umbriel template writes its colours next to this file. Its
    # hook rewrites this table unless it reads exactly like this, and the
    # file is read-only.
    [include.optional]
    files = ["noctalia.toml"]

    [general]
    autostart = ["noctalia"]
    show_cheatsheet = false

    [environment]
    NIXOS_OZONE_WL = "1"
    QT_QPA_PLATFORM = "wayland"
    QT_QPA_PLATFORMTHEME = "qt6ct"

    [input.keyboard]
    layout = "us"

    # niri switches off what its config leaves out, Umbriel keeps libinput's
    # default, which has disable-while-typing on
    [input.touchpad]
    tap = true
    disable_while_typing = false

    [input.focus]
    follows_mouse = "sloppy"

    [input.cursor]
    theme = "${config.home.pointerCursor.name}"
    size = ${toString osConfig.host.cursor.size}

    ${outputs}

    [appearance]
    prefer_no_csd = true
    border_width = 0
    corner_radius = 20

    [appearance.shadow]
    enabled = true
    softness = 30
    offset_x = 0
    offset_y = 5

    [colors]
    shadow = "#00000077"

    [layout]
    mode = "scrolling"
    gap = 5
    extent_presets = [0.33333, 0.5, 0.66667]

    [layout.scrolling]
    default_extent_fraction = 0.5
    center_focused = "never"
    center_underfull_strip = false

    [hot_corners.top_left]
    enabled = true
    action = "overview-open"

    # Bitwarden popouts. Opening rules are checked again when the first title
    # arrives, which niri needs the niri-autofloat watcher for.
    [[window_rule]]
    match.app_id = '^zen$'
    match.title = '^Extension: \(Bitwarden Password Manager\)'
    default_floating = true
    default_position = { x = 0, y = 120, anchor = "top" }

    [[window_rule]]
    match.app_id = '^helium$'
    match.title = '^Bitwarden( Password Manager)?$'
    default_floating = true
    default_position = { x = 0, y = 120, anchor = "top" }

    # The window Discord (or anything else) is streaming gets a thin red border.
    [[window_rule]]
    match.is_cast_target = true
    border_width = 2
    border_color_focused = "#E53935FF"
    border_color_unfocused = "#E53935FF"

    [[window_rule]]
    match.app_id = '^dev\.noctalia\.Noctalia$'
    default_floating = true
    default_floating_size_px = { width = 1080, height = 920 }

    # The portal's screen share picker
    [[window_rule]]
    match.app_id = '^dev\.noctalia\.UmbrielSharePicker$'
    default_floating = true
    default_floating_size_px = { width = 800, height = 600 }

    [[window_rule]]
    match.app_id = '^Pangolin-client$'
    default_floating = true

    # Pangolin's tray menu, see niri.nix
    [[window_rule]]
    match.app_id = '^Pangolin-client$'
    match.title = '^pangolin-client$'
    default_position = { x = ${pangolinMenuX}, y = -233, anchor = "bottom_right" }
    border_width = 0
    shadow = false

    [[window_rule]]
    match.app_id = '^steam$'
    match.title = '^notificationtoasts_\d+_desktop$'
    default_position = { x = 10, y = 10, anchor = "bottom_right" }
    default_focused = false

    # Defining this table drops Umbriel's built-in binds, so this is all of them.
    [keybinds]
    "Mod+Q" = "spawn ghostty +new-window"
    "Mod+E" = "spawn dolphin"
    "Mod+C" = { action = "window-close", repeat = false }
    "Mod+M" = { action = "session-quit", repeat = false }
    "Mod+V" = { action = "window-toggle-floating", repeat = false }
    "Mod+F" = { action = "window-toggle-maximize", repeat = false }
    "Mod+Shift+F" = { action = "window-toggle-fullscreen", repeat = false }
    "Mod+R" = "window-cycle-primary-extent"
    "Mod+Comma" = "window-consume-or-expel-left"
    "Mod+Period" = "window-consume-or-expel-right"
    "Mod+O" = { action = "overview-toggle", repeat = false }
    "Mod+P" = { action = "spawn umbriel-pip", repeat = false }
    "Mod+Shift+V" = { action = "spawn type-clipboard", repeat = false }
    "Mod+Shift+Slash" = { action = "cheatsheet-toggle", repeat = false }

    "Mod+Space" = "spawn noctalia msg panel-toggle launcher"
    "Mod+L" = "spawn noctalia msg session lock"
    # Umbriel has no screenshot UI of its own
    "Print" = { action = "spawn noctalia msg screenshot-region --directory ${screenshots}", repeat = false }
    "Shift+Print" = { action = "spawn noctalia msg screenshot-annotate --directory ${screenshots}", repeat = false }

    "Mod+Left" = "window-focus-or-output-left"
    "Mod+Right" = "window-focus-or-output-right"
    "Mod+Up" = "window-focus-or-output-up"
    "Mod+Down" = "window-focus-or-output-down"

    "Mod+Shift+Left" = "window-move-or-output-left"
    "Mod+Shift+Right" = "window-move-or-output-right"
    "Mod+Shift+Up" = "window-move-up"
    "Mod+Shift+Down" = "window-move-down"

    ${workspaceBinds}
    "Mod+WheelDown" = { action = "workspace-next", cooldown_ms = 150 }
    "Mod+WheelUp" = { action = "workspace-previous", cooldown_ms = 150 }

    "XF86AudioRaiseVolume" = { action = "spawn wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", allow_when_locked = true }
    "XF86AudioLowerVolume" = { action = "spawn wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", allow_when_locked = true }
    "XF86AudioMute" = { action = "spawn wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", allow_when_locked = true, repeat = false }
    "XF86AudioMicMute" = { action = "spawn wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", allow_when_locked = true, repeat = false }
    "XF86MonBrightnessUp" = { action = "spawn brightnessctl -e4 -n2 set 5%+", allow_when_locked = true }
    "XF86MonBrightnessDown" = { action = "spawn brightnessctl -e4 -n2 set 5%-", allow_when_locked = true }

    "XF86AudioNext" = { action = "spawn playerctl next", allow_when_locked = true, repeat = false }
    "XF86AudioPause" = { action = "spawn playerctl play-pause", allow_when_locked = true, repeat = false }
    "XF86AudioPlay" = { action = "spawn playerctl play-pause", allow_when_locked = true, repeat = false }
    "XF86AudioPrev" = { action = "spawn playerctl previous", allow_when_locked = true, repeat = false }
  '';
in

lib.mkIf osConfig.programs.umbriel.enable {
  home.packages = [ umbrielPip ];

  # Umbriel has no releases yet and renames keys between snapshots. A config
  # it rejects is replaced by its built-in defaults at login, so the build
  # fails instead.
  xdg.configFile."umbriel/config.toml".source =
    pkgs.runCommand "umbriel-config.toml" { nativeBuildInputs = [ umbriel ]; }
      ''
        umbriel config validate -c ${configText}
        cp ${configText} $out
      '';

  # A portals.conf in ~/.config is read before the one the portal package
  # ships, so without this an Umbriel session gets the gtk-only common file
  # and no screen sharing.
  xdg.portal = {
    extraPortals = [ osConfig.programs.umbriel.portalPackage ];
    config.umbriel = {
      default = [
        "umbriel"
        "gtk"
      ];
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
    };
  };
}
