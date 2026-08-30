{
  ...
}:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
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
