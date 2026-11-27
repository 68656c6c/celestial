{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Use the secrets only when this host can really decrypt them: its key must
  # be in .sops.yaml AND secrets.yaml must have been re-encrypted for it
  # (sops updatekeys). A key that is only listed locks the user out, because
  # the password file never appears.
  hostKey =
    let
      line = lib.findFirst (lib.hasInfix "&host_${config.networking.hostName} ") null (
        lib.splitString "\n" (builtins.readFile ../.sops.yaml)
      );
    in
    if line == null then null else lib.last (lib.splitString " " line);
  haveHostKey = hostKey != null && lib.hasInfix hostKey (builtins.readFile ../secrets/secrets.yaml);
in

{

  sops = {
    age.keyFile = "/var/lib/sops-nix/key";
    # Login password, so an unattended install boots into a usable machine
    secrets.artesia-password = lib.mkIf haveHostKey {
      sopsFile = ../secrets/secrets.yaml;
      neededForUsers = true;
    };
  };

  environment.sessionVariables.SOPS_AGE_KEY_CMD = lib.getExe (
    pkgs.writeShellApplication {
      name = "sops-age-key";
      text = ''
        key=${config.sops.age.keyFile}
        if [ -r "$key" ]; then
          exec cat "$key"
        fi
        exec /run/wrappers/bin/sudo cat "$key"
      '';
    }
  );

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
      systemd-boot.memtest86.enable = true;
    };
  };

  networking = {
    networkmanager = {
      enable = true;
    };
    enableIPv6 = false;
    firewall = {
      enable = true;
    };
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

  environment = {
    shells = [ pkgs.nushell ]; # pkexec requires the user shell to be in /etc/shells
    # Fix open with. Copied out, a link would pull all of Plasma into the closure.
    etc."xdg/menus/applications.menu".source = pkgs.runCommand "applications.menu" { } ''
      cp ${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu $out
    '';
    pathsToLink = [
      "/share/xdg-desktop-portal"
      "/share/applications"
    ];
  };

  users.users.artesia = {
    isNormalUser = true;
    description = "artesia";
    # A host whose key cannot read the secrets yet logs in with the password
    # setup-host.sh asked for and stored next to the key.
    hashedPasswordFile =
      if haveHostKey then config.sops.secrets.artesia-password.path else "/var/lib/sops-nix/password";
    extraGroups = [
      "networkmanager"
      "wheel"
      "ydotool"
    ];
  };

  security = {
    pam.services.login.enable = true;
    rtkit.enable = true;
    polkit.enable = true;
  };

  qt.enable = true;

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    optimise = {
      automatic = true;
      dates = [ "weekly" ]; # hardlinking the store is heavy IO, not while in use
    };
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [
        "https://celestial.cachix.org"
        "https://attic.cl2.artesia.cloud/celestial"
      ];
      trusted-public-keys = [
        "celestial.cachix.org-1:27CYgl28WMa6OGwoAK5WrTQVKmJIIhJYvOBpapp9ETk="
        "celestial:Ii3291OUFcJwNBkfMT3+oZn4V7yC+5XswXiWdoJ7peM="
      ];
      # a broken cache entry costs a local build, not a failed switch,
      # and an unreachable cache costs seconds, not minutes
      fallback = true;
      connect-timeout = 5;
    };
  };
}
