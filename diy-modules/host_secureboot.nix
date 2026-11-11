{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.host.secureboot;
in

{
  options.host.secureboot.enable = lib.mkEnableOption "Secure Boot: lanzaboote signs the boot files with this machine's own keys";

  # The keys live in /var/lib/sbctl. The installer creates them; the firmware
  # learns them afterwards, see scripts/secure-host.sh. Until it has, the
  # machine boots the same signed files with Secure Boot off.
  config = lib.mkIf cfg.enable {
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
    environment.systemPackages = [ pkgs.sbctl ];

    # Without keys the boot files cannot be signed and the switch dies halfway
    system.preSwitchChecks.securebootKeys = ''
      if [ ! -d /var/lib/sbctl/keys ]; then
        echo "host.secureboot is on but /var/lib/sbctl has no keys: sudo sbctl create-keys" >&2
        exit 1
      fi
    '';
  };
}
