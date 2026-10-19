{
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    fuzzel
    swaybg
    android-tools
    moonlight-qt
  ];
}
