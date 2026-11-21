{ pkgs, ... }:

{
  services = {
    # Fingerprint reader, for sudo, polkit and the lock screen. Enrol with
    # `fprintd-enroll`. The sensor (ELAN 04f3:0c5e) has no driver in libfprint
    # yet: this builds the elanmoc2 branch of merge request 330. Drop the
    # override once that is released.
    fprintd = {
      enable = true;
      package = pkgs.fprintd.override {
        libfprint = pkgs.libfprint.overrideAttrs (old: {
          version = "1.94.9-unstable-2025-07-27";
          src = pkgs.fetchFromGitLab {
            domain = "gitlab.freedesktop.org";
            owner = "depau";
            repo = "libfprint";
            rev = "11f0316d069cc90c154c8cb0e46478388c5e2a74";
            hash = "sha256-dxMls9Z5J9agesuNC46OoXAiYW/GcqWEEiAF7Y7DfwQ=";
          };
          patches = [ ];
          # The branch changes core behaviour without updating its tests.
          # Configuring still wants their python.
          doInstallCheck = false;
          nativeBuildInputs = old.nativeBuildInputs ++ old.nativeInstallCheckInputs;
        });
      };
    };

    # Mullvad daemon and its app (mullvad-vpn is the GUI build, plain
    # `mullvad` would be the command line only). Log in once from the app.
    mullvad-vpn = {
      enable = true;
      package = pkgs.mullvad-vpn;
    };

    # Firmware updates from HP: fwupdmgr refresh && fwupdmgr update
    fwupd.enable = true;
  };

  # The login screen keeps asking for the password: that is what unlocks the
  # keyring, a finger cannot. The lock screen authenticates against `login`
  # too, but noctalia drives the reader itself and cannot share it with PAM.
  security.pam.services = {
    ly.fprintAuth = false;
    login.fprintAuth = false;
  };
}
