{ pkgs, ... }:
{
  programs = {
    # GSettings backed by dconf for every GTK app (color scheme, squeekboard's
    # visibility key); without it settings land in a memory backend and vanish
    dconf.enable = true;
    # Apparently because it can mess with login shell, but I kinda want to go back to just nushell, we'll see later
    bash.interactiveShellInit = ''
      if ! [ "$TERM" = "dumb" ] && [ -z "$BASH_EXECUTION_STRING" ]; then
        exec nu
      fi
    '';
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
    vscode = {
      enable = true;
      # All from the Marketplace: <publisher>.<name> of the id, in lowercase. Only
      # releases that run on the VS Code installed here; an extension with none
      # is a missing attribute.
      extensions =
        with (pkgs.nix-vscode-extensions.forVSCodeVersion pkgs.vscode.version).vscode-marketplace-release;
        [
          jnoortheen.nix-ide
          ms-azuretools.vscode-docker
          eamodio.gitlens
          tamasfe.even-better-toml
          ms-python.python
          vscode-icons-team.vscode-icons
          thenuprojectcontributors.vscode-nushell-lang
          mads-hartmann.bash-ide-vscode
          rogalmic.bash-debug
          redhat.ansible
          redhat.vscode-yaml # ansible depends on it
          hashicorp.terraform
          esbenp.prettier-vscode
          ms-vscode.powershell
          bmuskalla.vscode-tldr
          coder.coder-remote
        ]
        # coder connects through it; the Marketplace has no release for this VS Code
        ++ [ pkgs.vscode-extensions.ms-vscode-remote.remote-ssh ];
    };
  };
}
