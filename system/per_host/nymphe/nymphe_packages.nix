{
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    swaybg
    android-tools
    moonlight-qt
  ];
}
