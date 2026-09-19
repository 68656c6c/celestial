{
  pkgs,
  # lib,
  # config,
  ...
}:

{
  services = {
    # greetd = {
    #   enable = true;
    #   useTextGreeter = true;
    #   settings = {
    #     default_session = {
    #       user = "greeter";
    #       command = ''
    #         ${lib.getExe pkgs.tuigreet}\
    #                     --time \
    #                     --xsessions ${sessionsDir}/xsessions
    #       '';
    #     };
    #   };
    # };
    displayManager = {
      ly.enable = true;
    };
    rpcbind.enable = true;
    flatpak.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
