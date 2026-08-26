{ pkgs, osConfig, ... }:

{
  programs.nushell = {
    enable = true;
    configFile.text = ''
      $env.NIXOS_OZONE_WL = 1
      $env.NH_OS_FLAKE = '.dotfiles'
      $env.XCURSOR_SIZE = ${builtins.toString osConfig.host.cursor.size}
      $env.config.show_banner = false
      $env.config.buffer_editor = "hx"
      $env.config.completions = {
          case_sensitive: false
          quick: true
          partial: true
          algorithm: "fuzzy"
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
