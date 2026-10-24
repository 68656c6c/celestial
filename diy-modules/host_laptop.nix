{
  config,
  lib,
  ...
}:

let
  cfg = config.host.laptop;
in

{
  options.host.laptop = {
    enable = lib.mkEnableOption "laptop power management: tlp, zram and AC-gated nix maintenance";

    thermald = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run thermald. Intel only, turn off on AMD machines.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tlp = {
      enable = true;
      # tlp-pd speaks the power-profiles-daemon D-Bus interface, so noctalia
      # and waybar keep their power profile widgets while tlp does the work.
      pd.enable = true;
    };
    services.power-profiles-daemon.enable = false;

    services.thermald.enable = cfg.thermald;

    zramSwap.enable = true;

    # Only clean the store on mains power
    systemd.services.nix-gc.unitConfig.ConditionACPower = true;
    systemd.services.nix-optimise.unitConfig.ConditionACPower = true;
  };
}
