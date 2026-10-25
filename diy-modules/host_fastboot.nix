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

    # Rust init and an immutable /etc assembled in the initrd instead of the
    # perl activation script. /etc is read-only, so stateful files such as
    # the sops key must live elsewhere (they do, /var/lib/sops-nix/key).
    system.nixos-init.enable = true;
    system.etc.overlay.enable = true;
    services.userborn.enable = true;

    # Mount the ESP on first use instead of during boot
    fileSystems."/boot".options = [
      "noauto"
      "x-systemd.automount"
    ];
  };
}
