{ pkgs, ... }:

{
  services = {
    # Mullvad daemon and its app (mullvad-vpn is the GUI build, plain
    # `mullvad` would be the command line only). Log in once from the app.
    mullvad-vpn = {
      enable = true;
      package = pkgs.mullvad-vpn;
    };

    # Firmware updates from HP: fwupdmgr refresh && fwupdmgr update
    fwupd.enable = true;
  };
}
