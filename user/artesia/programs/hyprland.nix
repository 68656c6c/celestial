{
  lib,
  osConfig,
  ...
}:

let
  cursorSize = toString osConfig.host.cursor.size;
  workspaceRules = lib.concatStrings (
    lib.genList (i: ''
      hl.workspace_rule({ workspace = "${toString (i + 1)}", monitor = "${(builtins.elemAt osConfig.host.monitors i).output}", persistent = true, default = true })
    '') (builtins.length osConfig.host.monitors)
  );
in

{
  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;
    systemd.variables = [ "--all" ];
    configType = "lua";

    settings = {
      monitor = map (m: {
        output = m.output;
        mode = m.mode;
        position = m.position;
        scale = m.scale;
      }) osConfig.host.monitors;

      env = [
        {
          _args = [
            "XCURSOR_SIZE"
            cursorSize
          ];
        }
        {
          _args = [
            "HYPRCURSOR_SIZE"
            cursorSize
          ];
        }
      ];

      config = {
        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          resize_on_border = false;
          allow_tearing = false;
          layout = "dwindle";
        };

        decoration = {
          rounding = 20;
          rounding_power = 2;
          active_opacity = 1.0;
          inactive_opacity = 1.0;
          shadow = {
            enabled = true;
            range = 4;
            render_power = 3;
            color = "0xee1a1a1a";
          };
          blur = {
            enabled = true;
            size = 3;
            passes = 2;
            vibrancy = 0.1696;
          };
        };

        dwindle = {
          preserve_split = true;
        };

        master = {
          new_status = "master";
        };

        scrolling = {
          fullscreen_on_one_column = true;
        };

        misc = {
          force_default_wallpaper = 0;
          disable_hyprland_logo = true;
        };

        cursor = {
          default_monitor = (builtins.elemAt osConfig.host.monitors 0).output;
        };

        input = {
          kb_layout = "us";
          kb_variant = "";
          kb_model = "";
          kb_options = "";
          kb_rules = "";
          follow_mouse = 1;
          sensitivity = 0;
          touchpad = {
            natural_scroll = false;
          };
        };
      };

      gesture = [
        {
          fingers = 3;
          direction = "horizontal";
          action = "workspace";
        }
      ];

      device = [
        {
          name = "epic-mouse-v1";
          sensitivity = -0.5;
        }
      ];

      bind = [
        {
          _args = [
            "SUPER + Q"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"ghostty\")")
          ];
        }
        {
          _args = [
            "SUPER + C"
            (lib.generators.mkLuaInline "hl.dsp.window.close()")
          ];
        }
        {
          _args = [
            "SUPER + M"
            (lib.generators.mkLuaInline "hl.dsp.exit()")
          ];
        }
        {
          _args = [
            "SUPER + E"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"nemo\")")
          ];
        }
        {
          _args = [
            "SUPER + V"
            (lib.generators.mkLuaInline "hl.dsp.window.float({ action = \"toggle\" })")
          ];
        }
        {
          _args = [
            "SUPER + P"
            (lib.generators.mkLuaInline "hl.dsp.window.pseudo()")
          ];
        }
        {
          _args = [
            "SUPER + J"
            (lib.generators.mkLuaInline "hl.dsp.layout(\"togglesplit\")")
          ];
        }

        {
          _args = [
            "SUPER + SPACE"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"noctalia msg panel-toggle launcher\")")
          ];
        }
        {
          _args = [
            "SUPER + L"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"noctalia msg session lock\")")
          ];
        }

        {
          _args = [
            "SUPER + left"
            (lib.generators.mkLuaInline "hl.dsp.focus({ direction = \"left\" })")
          ];
        }
        {
          _args = [
            "SUPER + right"
            (lib.generators.mkLuaInline "hl.dsp.focus({ direction = \"right\" })")
          ];
        }
        {
          _args = [
            "SUPER + up"
            (lib.generators.mkLuaInline "hl.dsp.focus({ direction = \"up\" })")
          ];
        }
        {
          _args = [
            "SUPER + down"
            (lib.generators.mkLuaInline "hl.dsp.focus({ direction = \"down\" })")
          ];
        }
      ]
      ++ (lib.concatMap (
        i:
        let
          n = if i == 9 then 0 else i + 1;
        in
        [
          {
            _args = [
              "SUPER + ${toString n}"
              (lib.generators.mkLuaInline "hl.dsp.focus({ workspace = ${toString (i + 1)} })")
            ];
          }
          {
            _args = [
              "SUPER + SHIFT + ${toString n}"
              (lib.generators.mkLuaInline "hl.dsp.window.move({ workspace = ${toString (i + 1)} })")
            ];
          }
        ]
      ) (lib.range 0 9))
      ++ [
        {
          _args = [
            "SUPER + S"
            (lib.generators.mkLuaInline "hl.dsp.workspace.toggle_special(\"magic\")")
          ];
        }
        {
          _args = [
            "SUPER + SHIFT + S"
            (lib.generators.mkLuaInline "hl.dsp.window.move({ workspace = \"special:magic\" })")
          ];
        }

        {
          _args = [
            "SUPER + mouse_down"
            (lib.generators.mkLuaInline "hl.dsp.focus({ workspace = \"e+1\" })")
          ];
        }
        {
          _args = [
            "SUPER + mouse_up"
            (lib.generators.mkLuaInline "hl.dsp.focus({ workspace = \"e-1\" })")
          ];
        }

        {
          _args = [
            "SUPER + mouse:272"
            (lib.generators.mkLuaInline "hl.dsp.window.drag()")
            { mouse = true; }
          ];
        }
        {
          _args = [
            "SUPER + mouse:273"
            (lib.generators.mkLuaInline "hl.dsp.window.resize()")
            { mouse = true; }
          ];
        }

        {
          _args = [
            "XF86AudioRaiseVolume"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+\")")
            {
              locked = true;
              repeating = true;
            }
          ];
        }
        {
          _args = [
            "XF86AudioLowerVolume"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-\")")
            {
              locked = true;
              repeating = true;
            }
          ];
        }
        {
          _args = [
            "XF86AudioMute"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle\")")
            {
              locked = true;
              repeating = true;
            }
          ];
        }
        {
          _args = [
            "XF86AudioMicMute"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle\")")
            {
              locked = true;
              repeating = true;
            }
          ];
        }
        {
          _args = [
            "XF86MonBrightnessUp"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"brightnessctl -e4 -n2 set 5%+\")")
            {
              locked = true;
              repeating = true;
            }
          ];
        }
        {
          _args = [
            "XF86MonBrightnessDown"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"brightnessctl -e4 -n2 set 5%-\")")
            {
              locked = true;
              repeating = true;
            }
          ];
        }

        {
          _args = [
            "XF86AudioNext"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"playerctl next\")")
            { locked = true; }
          ];
        }
        {
          _args = [
            "XF86AudioPause"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"playerctl play-pause\")")
            { locked = true; }
          ];
        }
        {
          _args = [
            "XF86AudioPlay"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"playerctl play-pause\")")
            { locked = true; }
          ];
        }
        {
          _args = [
            "XF86AudioPrev"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(\"playerctl previous\")")
            { locked = true; }
          ];
        }
      ];

      on = {
        _args = [
          "hyprland.start"
          (lib.generators.mkLuaInline ''
            function ()
              hl.exec_cmd("noctalia")
            end
          '')
        ];
      };
    };

    extraConfig = ''
      hl.config({
        general = {
          col = {
            active_border = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
            inactive_border = "rgba(595959aa)",
          },
        },
      })



      hl.window_rule({
        name = "float bitwarden",
        match = { class = "floorp", title = "Extension: (Bitwarden Password Manager) - Bitwarden — Ablaze Floorp"},
        float = true,
      })

      hl.window_rule({
        name = "suppress-maximize-events",
        match = { class = ".*" },
        suppress_event = "maximize",
      })

      hl.window_rule({
        name = "fix-xwayland-drags",
        match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
        no_focus = true,
      })

      hl.window_rule({
        name = "move-hyprland-run",
        match = { class = "hyprland-run" },
        move = "20 monitor_h-120",
        float = true,
      })

      hl.window_rule({
        match = { class = "dev.noctalia.Noctalia" },
        float = true,
        size = "1080 920",
      })

      ${workspaceRules}

      hl.layer_rule({
        match = { namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$" },
        no_anim = true,
        ignore_alpha = 0.5,
        blur = true,
        blur_popups = true,
      })

      require("noctalia").apply_theme()
    '';
  };

}
