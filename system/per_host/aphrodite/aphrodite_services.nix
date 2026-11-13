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

  # Graphical password prompts (systemctl, Bitwarden's "unlock with system
  # authentication", anything polkit) run PAM inside polkit-agent-helper, which
  # polkit 127 sandboxes away from every device. Let it reach the camera, or
  # howdy fails there in silence and only the password works. NixOS does the
  # same for U2F keys.
  systemd.services."polkit-agent-helper@".serviceConfig = {
    PrivateDevices = false;
    DeviceAllow = [
      "/dev/urandom r"
      "char-video4linux rw"
    ];
    # python with numpy and opencv maps executable memory
    MemoryDenyWriteExecute = false;
    # howdy's models, and the snapshots it may write
    ReadWritePaths = [
      "/var/lib/howdy"
      "-/var/log/howdy"
    ];
  };

  # The login screen keeps asking for the password: that is what unlocks the
  # keyring, a face cannot.
  security.pam.services.ly.howdy.enable = false;
}
