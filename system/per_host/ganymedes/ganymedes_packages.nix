{
  config,
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    stremio-linux-shell
  ];
}
