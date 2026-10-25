# Bootable installer image. Boots, picks the host by DMI product name, wipes
# the internal disk with disko and installs that host from the embedded copy
# of this flake. See installer/install.sh for the steps.
{
  config,
  lib,
  pkgs,
  inputs,
  modulesPath,
  ...
}:

let
  cfg = config.celestial.installer;
  system = pkgs.stdenv.hostPlatform.system;

  hostsJson = pkgs.writeText "celestial-hosts.json" (builtins.toJSON cfg.hosts);

  install = pkgs.writeShellApplication {
    name = "celestial-install";
    runtimeInputs = with pkgs; [
      age
      coreutils
      curl
      gawk
      gnused
      jq
      util-linux
      inputs.disko.packages.${system}.disko
    ];
    text = builtins.readFile ./install.sh;
  };
in

{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  options.celestial.installer = {
    flake = lib.mkOption {
      type = lib.types.path;
      description = "Source of this flake, embedded in the image at /etc/celestial.";
    };
    hosts = lib.mkOption {
      description = "Per host: DMI names and disk layout, taken from the host configurations.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            dmi = lib.mkOption { type = lib.types.listOf lib.types.str; };
            layout = lib.mkOption { type = lib.types.str; };
            swapSize = lib.mkOption { type = lib.types.nullOr lib.types.str; };
            espSize = lib.mkOption { type = lib.types.str; };
          };
        }
      );
    };
  };

  config = {
    image.baseName = lib.mkForce "celestial-installer";
    isoImage.volumeID = "CELESTIAL_INSTALL";
    isoImage.squashfsCompression = "zstd -Xcompression-level 6";
    boot.supportedFilesystems.zfs = lib.mkForce false;

    environment.etc.celestial.source = cfg.flake;
    environment.systemPackages = [
      install
      pkgs.age
      pkgs.jq
      inputs.disko.packages.${system}.disko
    ];

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [
        "https://attic.artesia.cloud/celestial"
        "https://celestial.cachix.org"
      ];
      trusted-public-keys = [
        "celestial:Pu6qm2/CCY/lcC9FVyXRNGBuXa8QzAGOQzA9BSIx51g="
        "celestial.cachix.org-1:27CYgl28WMa6OGwoAK5WrTQVKmJIIhJYvOBpapp9ETk="
      ];
    };

    # Runs on tty1 instead of the login prompt. Fails over to a shell.
    systemd.services.celestial-install = {
      description = "Unattended NixOS install";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "systemd-udev-settle.service"
      ];
      conflicts = [ "getty@tty1.service" ];
      unitConfig.OnFailure = "getty@tty1.service";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe install} ${hostsJson}";
        StandardInput = "tty-force";
        StandardOutput = "tty";
        StandardError = "tty";
        TTYPath = "/dev/tty1";
        TTYReset = true;
        TTYVHangup = true;
      };
    };

    system.stateVersion = "26.05";
  };
}
