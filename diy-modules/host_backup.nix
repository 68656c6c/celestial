{
  config,
  lib,
  ...
}:

let
  # On once secrets.yaml has a <hostname>-restic entry this host can decrypt:
  # a restic environment file (RESTIC_REPOSITORY, RESTIC_PASSWORD, backend
  # keys), one per host.
  secretName = "${config.networking.hostName}-restic";
  secrets = builtins.readFile ../secrets/secrets.yaml;
  hostKey = builtins.match ".*&host_${config.networking.hostName} (age1[a-z0-9]+).*" (
    builtins.readFile ../.sops.yaml
  );
  enabled =
    lib.hasInfix "${secretName}:" secrets && hostKey != null && lib.hasInfix (lib.head hostKey) secrets;
in

lib.mkIf enabled {
  sops.secrets.${secretName}.sopsFile = ../secrets/secrets.yaml;

  services.restic.backups.home = {
    environmentFile = config.sops.secrets.${secretName}.path;
    initialize = true;
    paths = [ "/home/artesia" ];
    exclude = [
      "/home/*/.cache"
      "/home/*/.local/share/Trash"
      "/home/*/.local/share/Steam/steamapps/common"
      "/home/*/.local/share/Steam/steamapps/shadercache"
      "/home/*/.local/share/Steam/steamapps/downloading"
      "/home/*/.local/share/Steam/steamrt64"
      "/home/*/.local/share/Steam/ubuntu12_32"
      "/home/*/.local/share/Steam/ubuntu12_64"
      "/home/*/.local/share/Steam/package"
      "/home/*/.local/share/Steam/appcache"
      "/home/*/.stremio-server/stremio-cache"
      "/home/*/.local/share/containers"
      "/home/*/.var/app/*/cache"
    ];
    extraBackupArgs = [
      "--exclude-caches"
      "--one-file-system"
    ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };

  host.laptop.onAC.restic-backups-home = "backup";
}
