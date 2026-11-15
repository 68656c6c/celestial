{
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    android-tools
    moonlight-qt
  ];
}
