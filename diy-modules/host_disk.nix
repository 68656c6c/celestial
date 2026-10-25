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
    };
  };

  # Mounts are by GPT partition label (disk-main-ESP, disk-main-swap,
  # disk-main-root), so the device path here never matters at runtime.
  # Existing installs get the labels from scripts/label-disk.sh.
  config.disko.devices =
    (import ../disko/layout.nix {
      device = "/dev/disk/by-id/set-by-the-installer";
      inherit (cfg) layout swapSize espSize;
    }).disko.devices;
}
