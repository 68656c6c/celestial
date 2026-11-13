{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Switches itself on per machine: the day secrets.yaml gains an entry named
  # pangolin-<hostname>, that host connects at boot. The value is three lines,
  # from a machine client made in the Pangolin dashboard:
  #   PANGOLIN_ENDPOINT=https://pangolin.example.org
  #   PANGOLIN_ID=...
  #   PANGOLIN_SECRET=...
  secretName = "pangolin-${config.networking.hostName}";
  enabled = lib.hasInfix "${secretName}:" (builtins.readFile ../secrets/secrets.yaml);

  # `pangolin service install` writes a unit into /etc, which NixOS does not
  # allow, so this is that same unit, declared.
  start = pkgs.writeShellApplication {
    name = "pangolin-client";
    runtimeInputs = [ pkgs.pangolin-cli ];
    text = ''
      exec pangolin up client --attach \
        --endpoint "$PANGOLIN_ENDPOINT" --id "$PANGOLIN_ID" --secret "$PANGOLIN_SECRET"
    '';
  };
in

lib.mkIf enabled {
  sops.secrets.${secretName}.sopsFile = ../secrets/secrets.yaml;

  systemd.services.pangolin-client = {
    description = "Pangolin client tunnel";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    # no network yet, server down: keep trying, never give up
    startLimitIntervalSec = 0;
    environment.HOME = "/var/lib/pangolin";
    serviceConfig = {
      EnvironmentFile = config.sops.secrets.${secretName}.path;
      ExecStart = lib.getExe start;
      Restart = "always";
      RestartSec = 10;
      StateDirectory = "pangolin";
    };
  };
}
