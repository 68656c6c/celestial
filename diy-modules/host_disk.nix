{
  config,
  lib,
  ...
}:

let
  cfg = config.host.disk;
in

{
  options.host = {
    dmi = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "Predator G9-791" ];
      description = "DMI product names of this machine (/sys/class/dmi/id/product_name). The installer picks the host by it.";
    };

    disk = {
      layout = lib.mkOption {
        type = lib.types.enum [
          "btrfs"
          "ext4"
        ];
        default = "btrfs";
        description = "Root filesystem. btrfs gets nix and home subvolumes.";
      };
      swapSize = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "16G";
        description = "Swap partition size, null for none (zram still applies on laptops).";
      };
      espSize = lib.mkOption {
        type = lib.types.str;
        default = "1G";
      };
      encrypt = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Root in LUKS, swap with a random key per boot. Only for a fresh install: an existing disk cannot be switched over.";
      };
    };
  };

  # Mounts are by GPT partition label (disk-main-ESP, disk-main-swap,
  # disk-main-root), so the device path here never matters at runtime.
  # Existing installs get the labels from scripts/label-disk.sh.
  config = {
    disko.devices =
      (import ../disko/layout.nix {
        device = "/dev/disk/by-id/set-by-the-installer";
        inherit (cfg)
          layout
          swapSize
          espSize
          encrypt
          ;
      }).disko.devices;

    # crypttab options (the TPM unlock) need the systemd initrd
    boot.initrd.systemd.enable = lib.mkIf cfg.encrypt true;

    # Switching an unencrypted install to this leaves a system that waits, on
    # the next boot, for a LUKS volume that is not there
    system.preSwitchChecks.encryptedRoot = lib.mkIf cfg.encrypt ''
      if [ ! -e /dev/mapper/cryptroot ]; then
        echo "host.disk.encrypt is on but this install is not encrypted: reinstall from the stick" >&2
        exit 1
      fi
    '';
  };
}
