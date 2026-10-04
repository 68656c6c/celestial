{ pkgs, ... }:
{
  programs = {
    # Apparently because it can mess with login shell, but I kinda want to go back to just nushell, we'll see later
    bash.interactiveShellInit = ''
      if ! [ "$TERM" = "dumb" ] && [ -z "$BASH_EXECUTION_STRING" ]; then
        exec nu
      fi
    '';
    hyprland.enable = true;
    hyprland.withUWSM = true;

    noctalia.recommendedServices.enable = true;
    sway = {
      wrapperFeatures.gtk = true;
      extraSessionCommands = ''
        export NIXOS_OZONE_WL=1
        export QT_QPA_PLATFORM=wayland
        export QT_QPA_PLATFORMTHEME=qt6ct
      '';
    };
    gpu-screen-recorder.enable = true;
    kdeconnect.enable = true;
    openvpn3.enable = true;
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
