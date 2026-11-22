{
  lib,
  ...
}:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "git.artesia.cloud" = {
        User = "git";
        Port = 222;
      };
      # No IdentityFile anywhere: the keys live in Bitwarden, its agent
      # (SSH_AUTH_SOCK, see system_services.nix) offers them.
      "github.com" = {
        User = "git";
      };
    }
    // lib.genAttrs (map (n: "moxmq${toString n}") (lib.range 1 6)) (host: {
      HostName = "${host}.artesia.cloud";
      User = "root";
    });
  };
}
