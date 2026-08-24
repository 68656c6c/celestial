{ pkgs, ... }:

{
  programs.nushell = {
    enable = true;
    configFile.text = ''
      $env.config = {
        show_banner: false

        completions: {
          case_sensitive: false
          quick: true
          partial: true
          algorithm: "fuzzy"
        }

        edit_mode: emacs

        hooks: {
          pre_prompt: [{ ||
            # Custom prompt hooks can go here
          }]
        }
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
