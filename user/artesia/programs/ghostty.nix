{ ... }:
{
  programs.ghostty = {
    enable = true;
    systemd.enable = true;
    settings = {
      shell-integration = "nushell";
      theme = "noctalia";
      font-size = 12;
      background-opacity = 1;
    };
  };
}
