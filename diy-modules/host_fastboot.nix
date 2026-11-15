{
  config,
  lib,
  ...
}:

let
  cfg = config.host.fastboot;
in

{
  options.host.fastboot.enable = lib.mkEnableOption "faster boot: nixos-init, /etc overlay, userborn, no boot menu";

  config = lib.mkIf cfg.enable {
    boot.loader.timeout = lib.mkDefault 0;

    # Rust init and /etc as an overlay assembled in the initrd instead of the
    # perl activation script. The overlay stays writable (overlay.mutable).
    system.nixos-init.enable = true;
    system.etc.overlay.enable = true;
    services.userborn.enable = true;

    # Mount the ESP on use instead of during boot, and let go of it again:
    # bootctl touches it two seconds in
    fileSystems."/boot".options = [
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=1min"
    ];
  };
}
