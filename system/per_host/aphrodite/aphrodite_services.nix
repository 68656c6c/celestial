{ ... }:

{
  services = {
    # Face unlock on the IR camera, for sudo, polkit and the lock screen.
    # Enrol with `sudo howdy add`; `sudo linux-enable-ir-emitter configure`
    # once if the IR light stays dark.
    howdy = {
      enable = true;
      control = "sufficient"; # a face is enough, the password still works
      settings.video.device_path = "/dev/v4l/by-path/pci-0000:00:14.0-usb-0:9:1.2-video-index0";
    };
    linux-enable-ir-emitter.enable = true;

    # Firmware updates from HP: fwupdmgr refresh && fwupdmgr update
    fwupd.enable = true;
  };

  # The login screen keeps asking for the password: that is what unlocks the
  # keyring, a face cannot.
  security.pam.services.ly.howdy.enable = false;
}
