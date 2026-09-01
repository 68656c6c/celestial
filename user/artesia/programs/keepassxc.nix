{ ... }:
{
  programs.keepassxc = {
    autostart = true;
    enable = true;
    settings = {
      FdoSecrets.Enabled = true;
    };
  };
}
