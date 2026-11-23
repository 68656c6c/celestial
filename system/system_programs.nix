{ pkgs, ... }:
{
  programs = {
    # GSettings backed by dconf for every GTK app (color scheme, squeekboard's
    # visibility key); without it settings land in a memory backend and vanish
    dconf.enable = true;
    # Apparently because it can mess with login shell, but I kinda want to go back to just nushell, we'll see later
    # Not for a bash that nushell or nix-shell started: /etc/bashrc runs before
    # the rcfile of nix develop, and replacing the shell there loses its environment.
    bash.interactiveShellInit = ''
      if ! [ "$TERM" = "dumb" ] && [ -z "$BASH_EXECUTION_STRING" ] && [ -z "$IN_NIX_SHELL" ] \
        && [ "$(${pkgs.procps}/bin/ps -o comm= -p "$PPID")" != nu ]; then
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
      # By Marketplace id, lowercase. Versions are pinned in
      # diy-modules/vscode_marketplace.lock.json, refreshed daily by CI.
      marketplaceExtensions = [
        "jnoortheen.nix-ide"
        "ms-azuretools.vscode-docker"
        "eamodio.gitlens"
        "tamasfe.even-better-toml"
        "ms-python.python"
        "vscode-icons-team.vscode-icons"
        "thenuprojectcontributors.vscode-nushell-lang"
        "mads-hartmann.bash-ide-vscode"
        "rogalmic.bash-debug"
        "redhat.ansible"
        "redhat.vscode-yaml" # ansible depends on it
        "hashicorp.terraform"
        "esbenp.prettier-vscode"
        "ms-vscode.powershell"
        "bmuskalla.vscode-tldr"
        "coder.coder-remote"
      ];
      # coder connects through it; the Marketplace has no release for this VS Code
      extensions = [ pkgs.vscode-extensions.ms-vscode-remote.remote-ssh ];
    };
  };
}
