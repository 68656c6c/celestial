{
  lib,
  pkgs,
  ...
}:

let
  cache = "celestial";
in
{
  systemd.user.services.attic-watch-store = {
    Unit = {
      Description = "Watch the nix store and push new paths to the ${cache} attic cache";
      Documentation = "https://docs.attic.rs/reference/attic-cli.html";
    };

    Service = {
      Type = "simple";
      ExecStart = "${lib.getExe pkgs.attic-client} watch-store --jobs 3 ${cache}";
      Restart = "always";
      RestartSec = 30;
      Nice = 19;
      IOSchedulingClass = "idle";
      CPUSchedulingPolicy = "batch";
    };

    Install.WantedBy = [ "default.target" ];
  };
}
