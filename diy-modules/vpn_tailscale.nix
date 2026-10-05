{
  config,
  lib,
  ...
}:

let
  cfg = config.vpn.tailscale;
in

{
  options.vpn.tailscale = {
    enable = lib.mkEnableOption "enable tailscale";

    ssh = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Tailscale SSH";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open firewall for Tailscale";
    };

    useRoutingFeatures = lib.mkOption {
      type = lib.types.enum [
        "client"
        "server"
        "both"
        "none"
      ];
      default = "client";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "artesia";
      description = "Tailscale operator user";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = cfg.useRoutingFeatures;
      openFirewall = cfg.openFirewall;
      permitCertUid = cfg.user;
      extraSetFlags = [ "--operator=${cfg.user}" ] ++ lib.optional cfg.ssh "--ssh";
    };
  };
}
