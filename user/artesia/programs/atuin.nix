{ ... }:

{
  programs.atuin = {
    enable = true;
    daemon.enable = true;
    enableNushellIntegration = true;
    settings = {
      auto_sync = true;
      sync_frequency = "2m";
      sync_address = "https://atuin.artesia.cloud";
    };
  };
}
