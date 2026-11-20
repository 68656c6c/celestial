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

    # lanzaboote ignores systemd-boot.memtest86, and an unsigned memtest will
    # not start under Secure Boot. Its garbage collection leaves these paths
    # alone. The stamp keeps the ESP unmounted at boot when nothing changed.
    systemd.services.memtest-esp =
      let
        esp = config.boot.loader.efi.efiSysMountPoint;
        src = pkgs.memtest86plus.efi;
        entry = pkgs.writeText "memtest86.conf" ''
          title Memtest86+
          efi /EFI/memtest86/memtest.efi
          sort-key o_memtest86
        '';
      in
      {
        description = "Signed Memtest86+ on the ESP";
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.sbsigntool ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = "memtest-esp";
        };
        script = ''
          stamp=/var/lib/memtest-esp/installed
          [ "$(cat $stamp 2>/dev/null)" = "${src} ${entry}" ] && exit 0
          install -d ${esp}/EFI/memtest86 ${esp}/loader/entries
          sbsign \
            --key ${config.boot.lanzaboote.privateKeyFile} \
            --cert ${config.boot.lanzaboote.publicKeyFile} \
            --output ${esp}/EFI/memtest86/memtest.efi ${src}
          install -m 0644 ${entry} ${esp}/loader/entries/memtest86.conf
          echo "${src} ${entry}" > $stamp
        '';
      };

    # Without keys the boot files cannot be signed and the switch dies halfway
    system.preSwitchChecks.securebootKeys = ''
      if [ ! -d /var/lib/sbctl/keys ]; then
        echo "host.secureboot is on but /var/lib/sbctl has no keys: sudo sbctl create-keys" >&2
        exit 1
      fi
    '';
  };
}
