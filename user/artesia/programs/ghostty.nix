{ ... }:
{
  programs.ghostty = {
    enable = true;
    systemd.enable = true;
    settings = {
      theme = "noctalia";
      font-size = 12;
      background-opacity = 1;
    };
  };
}
