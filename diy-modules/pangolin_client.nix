{
  config,
  pkgs,
  ...
}:

let
  client = pkgs.diy.pangolin-client;
in

{
  # The tray app: sign in once as a user, it connects again at every login.
  # It only talks to a root daemon, which runs the tunnels.
  environment.systemPackages = [ client ];

  # Upstream's unit, declared: its package would put it in /usr/lib
  systemd.services.pangolin-client = {
    description = "Pangolin client background service";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    # The client points the system DNS at its own proxy with `resolvconf`. A
    # unit's default PATH only has systemd's resolvconf, which talks to
    # systemd-resolved; that is not running here and the call fails. Put the
    # resolvconf this system really uses in front. The CLI is there so the
    # app finds it and does not offer to install one into /usr/local/bin.
    path = [
      config.networking.resolvconf.package
      pkgs.pangolin-cli
    ];
    serviceConfig = {
      ExecStart = "${client}/bin/pangolin-client --daemon";
      Restart = "on-failure";
      RestartSec = 2;
      KillMode = "mixed";
      TimeoutStopSec = 45;
      RuntimeDirectory = "pangolin-client";
      RuntimeDirectoryMode = "0755";
      StateDirectory = "pangolin-client";
      StateDirectoryMode = "0700";
      LogsDirectory = "pangolin-client";
      LogsDirectoryMode = "0755";
    };
  };

  # Machine defaults, each user's own settings go on top. New versions come
  # from the pin in diy-packages, the app cannot install one.
  environment.etc."pangolin-client/pangolin.json".text = builtins.toJSON {
    autoConnectAtLogin = true;
    autoUpdateChecksEnabled = false;
    checkForUpdatesButtonEnabled = false;
  };
}
