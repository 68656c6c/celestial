{
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
      "moxmq1" = {
        HostName = "moxmq1.artesia.cloud";
        User = "root";
      };
      "moxmq2" = {
        HostName = "moxmq2.artesia.cloud";
        User = "root";
      };
      "moxmq3" = {
        HostName = "moxmq3.artesia.cloud";
        User = "root";
      };
      "moxmq4" = {
        HostName = "moxmq4.artesia.cloud";
        User = "root";
      };
      "moxmq5" = {
        HostName = "moxmq5.artesia.cloud";
        User = "root";
      };
      "moxmq6" = {
        HostName = "moxmq6.artesia.cloud";
        User = "root";
      };
    };
  };
}
