{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.host.gpu;
in

{
  options.host.gpu = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "intel"
        "amd"
        "nvidia"
      ]
    );
    default = null;
    description = "GPU the desktop runs on. Picks the drivers and hardware video decode.";
  };

  config = lib.mkIf (cfg != null) {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = lib.optionals (cfg == "intel") (
        with pkgs;
        [
          intel-media-driver # iHD, Broadwell and newer
          intel-vaapi-driver # i965, older chips
          libvdpau-va-gl
        ]
      );
      extraPackages32 = lib.optionals (cfg == "intel") (
        with pkgs.driversi686Linux;
        [
          intel-media-driver
          intel-vaapi-driver
        ]
      );
    };

    # nvidia-vaapi-driver comes with the nvidia module
    environment.sessionVariables = {
      LIBVA_DRIVER_NAME =
        {
          intel = "iHD";
          amd = "radeonsi";
          nvidia = "nvidia";
        }
        .${cfg};
    }
    // lib.optionalAttrs (cfg == "nvidia") {
      NVD_BACKEND = "direct";
    };

    services.xserver.videoDrivers = lib.mkIf (cfg == "nvidia") [ "nvidia" ];
    hardware.nvidia.modesetting.enable = lib.mkIf (cfg == "nvidia") true;
  };
}
