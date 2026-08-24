{
  config,
  pkgs,
  lib,
  ...
}:

{
  services = {
    greetd = {
      enable = true;
      useTextGreeter = true;
      settings = {
        default_session = {
          user = "greeter";
          command = lib.getExe' pkgs.tuigreet "tuigreet --time --remember --remember-user-session";
        };
      };
    };
    printing.enable = true;
    rpcbind.enable = true;
    gnome.gnome-keyring.enable = true;
    flatpak.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
