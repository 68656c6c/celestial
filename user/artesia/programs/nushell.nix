{ pkgs, config, osConfig, ... }:

{
  programs.nushell = {
    enable = true;
    environmentVariables = {
      NIXOS_OZONE_WL = 1;
      NH_OS_FLAKE = "${config.home.homeDirectory}.dotfiles";
      XCURSOR_SIZE = ${builtins.toString osConfig.host.cursor.size};
      SSH_AUTH_SOCK = "${config.home.homeDirectory}.bitwarden-ssh-agent.sock";
    };
    configFile.text = ''
      $env.config.show_banner = false
      $env.config.buffer_editor = "hx"
      $env.config.completions = {
          case_sensitive: false
          quick: true
          partial: true
          algorithm: "fuzzy"
        }
      $env.config.history = {
        file_format: sqlite
        max_size: 1_000_000
        sync_on_enter: true
        isolation: false
      }
    '';
    extraConfig = ''
      def nwhich [flag: string] { readlink -f (which ... $flag) }
    '';
    shellAliases = {
      la = "eza -la";
      ll = "eza -l";
      l = "eza -l";
      ls = "eza";
      lt = "eza --tree";
      tree = "eza --tree";
    };
  };

  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
  };
}
