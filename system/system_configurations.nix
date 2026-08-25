{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{

  sops = {
    age.keyFile = "/etc/sops-age/keys";
    secrets = {
      dc01_ca = {
        sopsFile = ../secrets/dc01_ca.pem;
        format = "binary";
      };
    };
  };

  boot = {
    supportedFilesystems = [
      "nfs"
    ];
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
  };

  networking = {
    networkmanager = {
      enable = true;
      dns = "none";
      plugins = with pkgs; [
        networkmanager-openvpn
      ];
    };
    nameservers = [
      "10.44.4.2"
      "10.44.4.3"
    ];
    enableIPv6 = false;
    firewall = {
      enable = true;
    };
  };

  systemd = {
    mounts = [
      {
        type = "nfs";
        mountConfig = {
          Options = "defaults,noatime,noexec,sec=krb5p";
        };
        what = "nas.lab.local:/mnt/local-data/SMB";
        where = "/mnt/nas";
      }
    ];
    automounts = [
      {
        wantedBy = [ "multi-user.target" ];
        automountConfig = {
          TimeoutIdleSec = "600";
        };
        where = "/mnt/nas";
      }
    ];
  };

  time.timeZone = "Europe/Amsterdam";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocales = [
      "ja_JP.UTF-8/UTF-8"
      "ar_LB.UTF-8/UTF-8"
      "ar_SA.UTF-8/UTF-8"
      "ar_SY.UTF-8/UTF-8"
    ];
    extraLocaleSettings = {
      LC_ADDRESS = "nl_NL.UTF-8";
      LC_IDENTIFICATION = "nl_NL.UTF-8";
      LC_MEASUREMENT = "nl_NL.UTF-8";
      LC_MONETARY = "nl_NL.UTF-8";
      LC_NAME = "nl_NL.UTF-8";
      LC_NUMERIC = "nl_NL.UTF-8";
      LC_PAPER = "nl_NL.UTF-8";
      LC_TELEPHONE = "nl_NL.UTF-8";
      LC_TIME = "nl_NL.UTF-8";
    };
  };

  fonts.packages = with pkgs; [
    migmix
    atkinson-hyperlegible-next
    font-awesome
    nerd-fonts.jetbrains-mono
    noto-fonts
    amiri
  ];

  environment.shells = [ pkgs.nushell ]; # pkexec requires the user shell to be in /etc/shells

  users.users.artesia = {
    isNormalUser = true;
    description = "artesia";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.nushell;
  };

  users.users.doomly = {
    enable = false;
    isNormalUser = true;
    description = "doomly";
  };

  systemd.services.dc01-ca-cert = {
    description = "Install DC01 CA certificate";
    wantedBy = [ "multi-user.target" ];
    after = [ "sops-nix.service" ];
    requires = [ "sops-nix.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      cp ${config.sops.secrets.dc01_ca.path} /etc/ssl/certs/dc01_ca.pem
      update-ca-certificates
    '';
  };
  security = {
    pam.services.login.enable = true;
    rtkit.enable = true;
    polkit.enable = true;
  };

  # environment = {
  #   pathsToLink = [
  #     "/share/xdg-desktop-portal"
  #     "/share/applications"
  #   ];
  # };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
