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
  # allow, so this is that same unit, declared. The credentials go in through
  # the environment (the CLI reads PANGOLIN_CLIENT_ID and _SECRET, and
  # PANGOLIN_ENDPOINT as it is): as flags they show up in `ps` and in
  # `systemctl status` for every user. Either spelling works in the secret.
  start = pkgs.writeShellApplication {
    name = "pangolin-client";
    runtimeInputs = [ pkgs.pangolin-cli ];
    text = ''
      export PANGOLIN_CLIENT_ID="''${PANGOLIN_CLIENT_ID:-''${PANGOLIN_ID:?no client id in the secret}}"
      export PANGOLIN_CLIENT_SECRET="''${PANGOLIN_CLIENT_SECRET:-''${PANGOLIN_SECRET:?no client secret in the secret}}"
      : "''${PANGOLIN_ENDPOINT:?no endpoint in the secret}"
      unset PANGOLIN_ID PANGOLIN_SECRET
      exec pangolin up client --attach
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
    # The client points the system DNS at its own proxy with `resolvconf`. A
    # unit's default PATH only has systemd's resolvconf, which talks to
    # systemd-resolved; that is not running here, the call fails and the
    # client gives up before it registers, once a minute, for ever. Put the
    # resolvconf this system really uses in front.
    path = [ config.networking.resolvconf.package ];
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
