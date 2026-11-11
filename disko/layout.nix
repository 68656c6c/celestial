# One disk, GPT: ESP, swap, root. Used twice: imported by diy-modules/host_disk.nix
# to describe every host (device is a placeholder there, mounts go by partition
# label), and run by the installer with --argstr device/layout/espSize and
# --argstr swapSize (or --arg swapSize null for no swap partition) to format
# the disk it detected. With encrypt, root sits in LUKS (the installer passes
# the file holding the recovery passphrase) and swap gets a throwaway key on
# every boot, so nothing on the disk but the ESP is readable.
{
  device,
  layout ? "btrfs",
  swapSize ? "16G",
  espSize ? "1G",
  encrypt ? false,
  passwordFile ? null,
  ...
}:

let
  root =
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
in

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
        root = {
          size = "100%";
          content =
            if encrypt then
              {
                type = "luks";
                name = "cryptroot";
                settings = {
                  allowDiscards = true;
                  # TPM first when a key is enrolled (scripts/secure-host.sh),
                  # otherwise the passphrase prompt
                  crypttabExtraOpts = [ "tpm2-device=auto" ];
                };
                content = root;
              }
              // (if passwordFile == null then { } else { inherit passwordFile; })
            else
              root;
        };
      }
      // (
        if swapSize == null then
          { }
        else
          {
            swap = {
              size = swapSize;
              content = {
                type = "swap";
                randomEncryption = encrypt;
              };
            };
          }
      );
    };
  };
}
