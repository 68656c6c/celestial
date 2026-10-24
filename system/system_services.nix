{
  ...
}:

{
  services = {
    blueman.enable = true;
    displayManager = {
      ly = {
        enable = true;
        settings = {
          animation = "colormix";
          animation_frame_delay = 20;
          colormix_col1 = "0x00C8102E";
          colormix_col2 = "0x00FF5A36";
          colormix_col3 = "0x20000000";
          bg = "0x20000000";
          fg = "0x00FFE4E1";
          border_fg = "0x00E0303A";
          error_fg = "0x01FFB347";
          bigclock = "en";
          clock = "%a %d %b";
          hide_version_string = true;
          clear_password = true;
        };
      };
    };
    gnome.gnome-keyring.enable = true;
    flatpak.enable = true;
    # Daemon up on every host, never connected on its own: `tailscale up` is a manual step
    tailscale = {
      enable = true;
      openFirewall = true;
      useRoutingFeatures = "client";
      permitCertUid = "artesia";
      extraSetFlags = [
        "--operator=artesia"
        "--ssh"
      ];
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
