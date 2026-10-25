# One disk, GPT: ESP, swap, root. Used twice: imported by diy-modules/host_disk.nix
# to describe every host (device is a placeholder there, mounts go by partition
# label), and run by the installer with --argstr device/layout/swapSize/espSize
# to format the disk it detected.
{
  device,
  layout ? "btrfs",
  swapSize ? "16G",
  espSize ? "1G",
  ...
}:

{
  disko.devices.disk.main = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = espSize;
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [
              "fmask=0077"
              "dmask=0077"
            ];
          };
        };
        swap = {
          size = swapSize;
          content.type = "swap";
        };
        root = {
          size = "100%";
          content =
            if layout == "btrfs" then
              {
                type = "btrfs";
                extraArgs = [ "-f" ];
                mountpoint = "/";
                subvolumes = {
                  nix.mountpoint = "/nix";
                  home.mountpoint = "/home";
                };
              }
            else
              {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
        };
      };
    };
  };
}
