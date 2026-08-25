{ config, pkgs, ... }:
{
  programs = {
    hyprland.enable = true;
    niri.enable = true;
    gpu-screen-recorder.enable = true;
    kdeconnect.enable = true;
    steam = {
      enable = true;
      package = pkgs.millennium-steam;
      extest.enable = true; # steam input in wayland
    };
    vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
        ms-azuretools.vscode-docker
        eamodio.gitlens
        tamasfe.even-better-toml
        ms-python.python
        vscode-icons-team.vscode-icons
      ];
    };
  };
}
