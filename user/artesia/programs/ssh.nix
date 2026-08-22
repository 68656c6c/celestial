{ pkgs }:
{
  programs.ssh = {
    enable = true;
    settings = {
      "git.artesia.cloud" = {
        HostName = "git.artesia.cloud";
        User = "git";
        Port = 222;
        IdentityFile = "~/.ssh/id_rsa";
      };
      "github.com" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/id_rsa";
      };
    };
  };
}
