{
  config,
  lib,
  ...
}:

let
  # On for a host once secrets.yaml has a <hostname>-restic entry, like
  # host_pangolin.nix. The value is a restic environment file
  # (RESTIC_REPOSITORY, RESTIC_PASSWORD, backend keys). One entry per host:
  # separate repositories, though every host key can decrypt every entry.
  secretName = "${config.networking.hostName}-restic";
  enabled = lib.hasInfix "${secretName}:" (builtins.readFile ../secrets/secrets.yaml);
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
