{
  pkgs,
  ...
}:

{

  sops = {
    age.keyFile = "/var/lib/sops-nix/key";
  };

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
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
    # Fix open with
    etc."xdg/menus/applications.menu".source =
      "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";
    pathsToLink = [
      "/share/xdg-desktop-portal"
      "/share/applications"
    ];
  };

  users.users.artesia = {
    isNormalUser = true;
    description = "artesia";
    extraGroups = [
      "networkmanager"
      "wheel"
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
      dates = [ "20:00" ];
    };
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = [
        "https://celestial.cachix.org"
        "https://attic.artesia.cloud/celestial"
      ];
      trusted-public-keys = [
        "celestial.cachix.org-1:27CYgl28WMa6OGwoAK5WrTQVKmJIIhJYvOBpapp9ETk="
        "celestial:Pu6qm2/CCY/lcC9FVyXRNGBuXa8QzAGOQzA9BSIx51g="
      ];
    };
  };
}
