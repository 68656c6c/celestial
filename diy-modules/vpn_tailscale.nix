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
    sops.secrets.tsauth_key = {
      sopsFile = ../secrets/tsauth.key;
      format = "binary";
    };

    services.tailscale = {
      enable = true;
      authKeyFile = config.sops.secrets.tsauth_key.path;
      useRoutingFeatures = cfg.useRoutingFeatures;
      openFirewall = cfg.openFirewall;
      permitCertUid = cfg.user;
      extraUpFlags = lib.optional cfg.ssh "--ssh";
      extraSetFlags = [ "--operator=${cfg.user}" ];
    };
  };
}
