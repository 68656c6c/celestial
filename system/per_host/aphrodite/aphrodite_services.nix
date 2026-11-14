{ pkgs, ... }:

{
  services = {
    # Face unlock on the IR camera, for sudo, polkit and the lock screen.
    # Enrol with `sudo howdy add`; `sudo linux-enable-ir-emitter configure`
    # once if the IR light stays dark.
    howdy = {
      enable = true;
      control = "sufficient"; # a face is enough, the password still works
      # Bitwarden asks polkit twice at once, and two scans cannot share the
      # camera: the loser fails, the agent retries, and they keep colliding.
      # Queue the scans instead, see howdy_camera_queue.py.
      package = pkgs.howdy.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace howdy/src/compare.py \
            --replace-fail \
              'video_capture = VideoCapture(config)' \
              'import camera_queue; video_capture = camera_queue.open_camera(VideoCapture, config, user)' \
            --replace-fail \
              '# End peacefully' \
              'camera_queue.approved(user)'
        '';
        postInstall = (old.postInstall or "") + ''
          install -m 444 ${./howdy_camera_queue.py} $out/lib/howdy/camera_queue.py
        '';
      });
      settings.video.device_path = "/dev/v4l/by-path/pci-0000:00:14.0-usb-0:9:1.2-video-index0";
    };
    linux-enable-ir-emitter.enable = true;

    # Mullvad daemon and its app (mullvad-vpn is the GUI build, plain
    # `mullvad` would be the command line only). Log in once from the app.
    mullvad-vpn = {
      enable = true;
      package = pkgs.mullvad-vpn;
    };

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
    # howdy's models, the snapshots it may write, and the approval stamps of
    # the camera queue
    ReadWritePaths = [
      "/var/lib/howdy"
      "-/var/log/howdy"
      "/run/howdy"
    ];
  };

  # The camera queue: a lock readable by all, since a scan may run as root
  # (sudo, polkit) or as the user (lock screen) and flock needs no more, and a
  # root-only directory for the approval stamps.
  systemd.tmpfiles.rules = [
    "f /run/howdy-camera.lock 0644 root root -"
    "d /run/howdy 0755 root root -"
  ];

  # The login screen keeps asking for the password: that is what unlocks the
  # keyring, a face cannot.
  security.pam.services.ly.howdy.enable = false;
}
