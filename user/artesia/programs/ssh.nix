{
  ...
}:
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
      "*" = {
        ForwardAgent = false;
        AddKeysToAgent = "no";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };
    };
  };
}
