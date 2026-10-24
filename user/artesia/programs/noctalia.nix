{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  primaryMonitor =
    if osConfig.host.monitors == [ ] then null else builtins.head osConfig.host.monitors;

  primaryOutput = if primaryMonitor == null then "eDP-1" else primaryMonitor.output;
  screenWidth = if primaryMonitor == null then 1920 else primaryMonitor.width;
  screenHeight = if primaryMonitor == null then 1080 else primaryMonitor.height;

  centerX = screenWidth / 2;
  centerY = screenHeight / 2;

  stateDir = "${config.xdg.stateHome}/noctalia";

  settings = {
    config_version = 14;

    bar.default = {
      font_family = "Atkinson Hyperlegible Next";
      position = "bottom";
    };

    calendar.enabled = true;

    control_center.calendar.show_week_numbers = true;

    dock = {
      auto_hide = true;
      launcher_icon = "border-top-plus";
      launcher_position = "start";
    };

    location.address = "Groningen";

    nightlight.temperature_night = 3100;

    shell = {
      avatar_path = "${config.home.homeDirectory}/Pictures/20260415_193158.jpg";
      font_family = "Atkinson Hyperlegible Next";
      panel = {
        clipboard_placement = "attached";
        launcher_placement = "attached";
      };
    };

    theme = {
      palette_source = "wallpaper";
      wallpaper_scheme = "vibrant";
      templates = {
        builtin_ids = [
          "gtk3"
          "gtk4"
          "ghostty"
          "helix"
          "kcolorscheme"
          "niri"
          "qt"
          "starship"
        ];
        community_ids = [
          "claude-code"
          "pywalfox-beta4"
          "zen-browser"
          "discord"
          "telegram"
          "blender"
          "gimp"
          "obsidian"
          "vscode"
          "heroiclauncher"
          "prismlauncher"
          "obs"
        ];
      };
    };

    wallpaper = {
      directory = "${config.home.homeDirectory}/.dotfiles/wallpapers/";
      transition_on_startup = true;
      automation = {
        enabled = true;
        interval_seconds = 600;
      };
    };

    desktop_widgets = {
      schema_version = 2;
      widget_order = [
        "desktop-widget-0000000000000001"
        "desktop-widget-0000000000000002"
      ];
      grid = {
        cell_size = 16;
        major_interval = 4;
        visible = true;
      };
      widget = {
        "desktop-widget-0000000000000001" = {
          type = "clock";
          output = primaryOutput;
          cx = 203.5;
          cy = 202.5;
          box_width = 0.0;
          box_height = 0.0;
          placement_width = screenWidth * 1.0;
          placement_height = screenHeight * 1.0;
          rotation = 0.0;
        };
        "desktop-widget-0000000000000002" = {
          type = "fancy_audio_visualizer";
          output = primaryOutput;
          cx = centerX * 1.0;
          cy = centerY * 1.0;
          box_width = 0.0;
          box_height = 0.0;
          placement_width = screenWidth * 1.0;
          placement_height = screenHeight * 1.0;
          rotation = 0.0;
          settings.background = false;
        };
      };
    };

    lockscreen_widgets = {
      enabled = false;
      schema_version = 2;
      widget_order = [ "lockscreen-login-box@${primaryOutput}" ];
      grid = {
        cell_size = 16;
        major_interval = 4;
        visible = true;
      };
      widget."lockscreen-login-box@${primaryOutput}" = {
        type = "login_box";
        output = primaryOutput;
        cx = centerX * 1.0;
        cy = (screenHeight - 182) * 1.0;
        box_width = 810.0;
        box_height = 196.0;
        placement_width = screenWidth * 1.0;
        placement_height = screenHeight * 1.0;
        rotation = 0.0;
        settings = {
          background_color = "surface_variant";
          background_opacity = 0.88;
          background_radius = 12.0;
          center_password_text = false;
          input_opacity = 1.0;
          input_radius = 6.0;
          layout = "regular";
          show_caps_lock = true;
          show_keyboard_layout = true;
          show_login_button = true;
          show_media = true;
          show_session_buttons = true;
          show_unlock_hint = true;
          show_weather = true;
        };
      };
    };
  };

  declaredJson = pkgs.writeText "noctalia-declared.json" (builtins.toJSON settings);
in
{
  xdg.configFile."noctalia/plugins.json".text = builtins.toJSON {
    version = 2;
    sources = [
      {
        enabled = true;
        name = "Noctalia Plugins";
        url = "https://github.com/noctalia-dev/noctalia-plugins";
      }
    ];
    states.privacy-indicator = {
      enabled = true;
      sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
    };
  };

  home.activation.noctaliaSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    stateFile="${stateDir}/settings.toml"
    tmpFile="$(${pkgs.coreutils}/bin/mktemp)"

    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "${stateDir}"

    if [ -f "$stateFile" ]; then
      live="$(${pkgs.yj}/bin/yj -tj < "$stateFile")"
    else
      live='{}'
    fi

    ${pkgs.coreutils}/bin/printf '%s\n%s\n' "$live" "$(< ${declaredJson})" \
      | ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
      | ${pkgs.yj}/bin/yj -jt > "$tmpFile"

    $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0644 "$tmpFile" "$stateFile"
    ${pkgs.coreutils}/bin/rm -f "$tmpFile"
  '';

  home.activation.noctaliaGtkStub = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatMapStrings
      (dir: ''
        if [ ! -e "${config.xdg.configHome}/${dir}/noctalia.css" ]; then
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "${config.xdg.configHome}/${dir}"
          $DRY_RUN_CMD ${pkgs.coreutils}/bin/touch "${config.xdg.configHome}/${dir}/noctalia.css"
        fi
      '')
      [
        "gtk-3.0"
        "gtk-4.0"
      ]
  );
}
