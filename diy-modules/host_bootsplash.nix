{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.host.bootsplash;
in

{
  options.host.bootsplash = {
    enable = lib.mkEnableOption "boot animation (plymouth) over the boot text, Esc switches between the two";

    theme = lib.mkOption {
      type = lib.types.str;
      default = "circle_hud";
      description = "Theme from adi1090x-plymouth-themes, by its directory name.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      plymouth = {
        enable = true;
        theme = cfg.theme;
        # the pack holds 80 themes, only the chosen one goes into the initrd
        themePackages = [
          (pkgs.adi1090x-plymouth-themes.override { selected_themes = [ cfg.theme ]; })
        ];
      };

      # Plymouth will not draw on the firmware framebuffer, it waits for the
      # real graphics driver. Loaded from the root disk that is seconds into
      # the boot, with the vendor logo sitting there until then, so load it
      # in the initrd. (nvidia has no such driver to load early.)
      initrd.kernelModules =
        lib.optional (config.host.gpu == "intel") "i915"
        ++ lib.optional (config.host.gpu == "amd") "amdgpu";

      # Keep the text off the animation. It is all still there behind Esc.
      consoleLogLevel = 3;
      initrd.verbose = false;
      kernelParams = [
        "quiet"
        "udev.log_level=3"
        "rd.udev.log_level=3"
        "systemd.show_status=false"
        "rd.systemd.show_status=false"
      ];
    };
  };
}
