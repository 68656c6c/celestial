# Bootable installer image. Boots, clones this repo, picks the host by DMI
# product name (or creates one), wipes the internal disk with disko and
# installs. See installer/install.sh for the steps.
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

  install = pkgs.writeShellApplication {
    name = "celestial-install";
    runtimeInputs = with pkgs; [
      age
      coreutils
      curl
      gawk
      git
      gnugrep
      gnused
      jq
      mkpasswd
      nixfmt
      sbctl
      cryptsetup
      findutils
      util-linux
      inputs.disko.packages.${system}.disko
    ];
    text = builtins.readFile ./install.sh;
  };
in

{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  options.celestial.installer.repo = lib.mkOption {
    type = lib.types.str;
    default = "https://github.com/68656c6c/celestial.git";
    description = "Where the installer clones the configuration from.";
  };

  config = {
    image.baseName = lib.mkForce "celestial-installer";
    isoImage.volumeID = "CELESTIAL_INSTALL";
    isoImage.squashfsCompression = "zstd -Xcompression-level 6";
    boot.supportedFilesystems.zfs = lib.mkForce false;

    environment.systemPackages = [
      install
      pkgs.age
      pkgs.git
      pkgs.jq
      inputs.disko.packages.${system}.disko
    ];

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # nixos-install reads this file, not the target's settings, so the
      # CachyOS kernel for io has to be reachable from here too. attic is
      # private: install.sh adds it when the stick brings the token, without
      # one it would only cost retries.
      substituters = [
        "https://celestial.cachix.org"
        "https://nyx-cache.chaotic.cx/"
      ];
      trusted-public-keys = [
        "celestial:Pu6qm2/CCY/lcC9FVyXRNGBuXa8QzAGOQzA9BSIx51g="
        "celestial.cachix.org-1:27CYgl28WMa6OGwoAK5WrTQVKmJIIhJYvOBpapp9ETk="
        "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
      ];
      # a cache that is down or wants a token costs seconds, not the install
      fallback = true;
      connect-timeout = 5;
    };

    # Runs on tty1 instead of the login prompt. Fails over to a shell, where
    # `celestial-install <repo url>` starts it again.
    systemd.services.celestial-install = {
      description = "NixOS install";
      wantedBy = [ "multi-user.target" ];
      after = [
        "NetworkManager.service"
        "systemd-udev-settle.service"
      ];
      conflicts = [ "getty@tty1.service" ];
      unitConfig.OnFailure = "getty@tty1.service";
      # nix, nixos-install, nixos-generate-config, nmtui, systemctl
      path = [ "/run/current-system/sw" ];
      environment.HOME = "/root";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe install} ${cfg.repo}";
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
