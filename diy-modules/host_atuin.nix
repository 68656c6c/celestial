{
  config,
  lib,
  pkgs,
  ...
}:

let
  # On once secrets.yaml has an `atuin` entry, like host_backup.nix. One
  # entry for all hosts, three lines:
  #   ATUIN_USERNAME=...
  #   ATUIN_PASSWORD=...
  #   ATUIN_ENCRYPTION_KEY="the words `atuin key` prints on a logged-in host"
  enabled = lib.hasInfix "\natuin:" (builtins.readFile ../secrets/secrets.yaml);

  # atuin keeps its session in a database, so there is no file to hand it:
  # the login itself has to run, once per host.
  login = pkgs.writeShellApplication {
    name = "atuin-login";
    runtimeInputs = [
      pkgs.atuin
      config.systemd.package
    ];
    text = ''
      if atuin status > /dev/null 2>&1; then exit 0; fi
      atuin login -u "''${ATUIN_USERNAME:?no username in the secret}"
      # Until this login atuin used a key it made for itself: a running daemon
      # still holds it, and what was recorded with it is unreadable for every
      # other host. Drop those records and write them again from the local
      # history, before anything is uploaded.
      systemctl --user try-restart atuin-daemon.service
      atuin store purge
      atuin history init-store
      atuin sync
    '';
  };
in

lib.mkIf enabled {
  sops.secrets.atuin = {
    sopsFile = ../secrets/secrets.yaml;
    owner = "artesia";
  };

  systemd.user.services.atuin-login = {
    description = "Log atuin in to the sync server";
    wantedBy = [ "default.target" ];
    unitConfig.ConditionUser = "artesia";
    # no network yet, server down: try again
    startLimitIntervalSec = 0;
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets.atuin.path;
      ExecStart = lib.getExe login;
      Restart = "on-failure";
      RestartSec = 60;
    };
  };
}
