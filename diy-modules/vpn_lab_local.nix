{
  config,
  lib,
  ...
}:

let
  cfg = config.lab_local.vpn;
  host = config.networking.hostName;
in

{
  options.lab_local.vpn = {
    enable = lib.mkEnableOption "enable vpn";

    name = lib.mkOption {
      type = lib.types.str;
      default = "selective";
    };

    updateDns = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.vpn-config = {
      sopsFile = ../secrets/vpn_${host}.ovpn;
      format = "binary";
      restartUnits = [ "openvpn-${cfg.name}.service" ];
    };

    services.openvpn.servers.${cfg.name} = {
      autoStart = true;
      updateResolvConf = cfg.updateDns;
      config = "config ${config.sops.secrets.vpn-config.path}";
    };
  };
}
