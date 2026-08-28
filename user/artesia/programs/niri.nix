{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  cursorSize = toString osConfig.host.cursor.size;
  monitorKDL = lib.concatMapStringsSep "\n" (m: ''
    output "${m.output}" {
      ${if m.mode != "" then ''mode "${m.mode}"'' else ""}
      ${
        if m.position != "" then
          let
            parts = lib.splitString "x" m.position;
          in
          "position x=${builtins.elemAt parts 0} y=${builtins.elemAt parts 1}"
        else
          ""
      }
      ${if m.scale != 1 then "scale ${toString m.scale}" else ""}
    }
  '') osConfig.host.monitors;
in

{
  xdg.configFile."niri/config.kdl".text = ''
    spawn-at-startup "noctalia"

    hotkey-overlay {
      skip-at-startup
    }

    environment {
      XCURSOR_SIZE "${cursorSize}"
      HYPRCURSOR_SIZE "${cursorSize}"
    }

    ${monitorKDL}

    binds {
      Mod+Q { spawn "${pkgs.ghostty}/bin/ghostty"; }
      Mod+E { spawn "${pkgs.nemo}/bin/nemo"; }
      Mod+C { close-window; }
      Mod+M { quit; }
      Mod+V { toggle-window-floating; }
      Mod+F { maximize-column; }
      Mod+Shift+F { fullscreen-window; }

      Mod+Left { focus-column-left; }
      Mod+Right { focus-column-right; }
      Mod+Up { focus-window-up; }
      Mod+Down { focus-window-down; }

      Mod+Shift+Left { move-column-left; }
      Mod+Shift+Right { move-column-right; }
      Mod+Shift+Up { move-window-up; }
      Mod+Shift+Down { move-window-down; }

      Mod+1 { focus-workspace 1; }
      Mod+2 { focus-workspace 2; }
      Mod+3 { focus-workspace 3; }
      Mod+4 { focus-workspace 4; }
      Mod+5 { focus-workspace 5; }
      Mod+6 { focus-workspace 6; }
      Mod+7 { focus-workspace 7; }
      Mod+8 { focus-workspace 8; }
      Mod+9 { focus-workspace 9; }

      Mod+Shift+1 { move-column-to-workspace 1; }
      Mod+Shift+2 { move-column-to-workspace 2; }
      Mod+Shift+3 { move-column-to-workspace 3; }
      Mod+Shift+4 { move-column-to-workspace 4; }
      Mod+Shift+5 { move-column-to-workspace 5; }
      Mod+Shift+6 { move-column-to-workspace 6; }
      Mod+Shift+7 { move-column-to-workspace 7; }
      Mod+Shift+8 { move-column-to-workspace 8; }
      Mod+Shift+9 { move-column-to-workspace 9; }

      Mod+Space { spawn "${pkgs.noctalia}/bin/noctalia" "msg" "panel-toggle" "launcher"; }
      Mod+L { spawn "${pkgs.noctalia}/bin/noctalia" "msg" "session" "lock"; }
    }
  '';
}
