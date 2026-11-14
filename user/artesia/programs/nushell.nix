{
  config,
  osConfig,
  ...
}:

{
  programs.nushell = {
    enable = true;
    shellAliases = {
      la = "eza -la";
      ll = "eza -l";
      l = "eza -l";
      ls = "eza";
      lt = "eza --tree";
      tree = "eza --tree";
    };
    environmentVariables = {
      # nushell does not load home.sessionVariables, so helix.defaultEditor
      # never reaches it and NixOS's EDITOR=nano wins (sops, git, ...)
      EDITOR = "hx";
      VISUAL = "hx";
      # the same values the other shells get, by name: the whole set cannot be
      # taken over, some entries use sh expansions
      inherit (config.home.sessionVariables)
        NIXOS_OZONE_WL
        WLR_NO_HARDWARE_CURSORS
        NH_OS_FLAKE
        XCURSOR_SIZE
        ;
      SSH_AUTH_SOCK = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
      QT_QPA_PLATFORM = "wayland";
      QT_QPA_PLATFORMTHEME = "qt6ct";
      SOPS_AGE_KEY_FILE = osConfig.sops.age.keyFile;
    };
    settings = {
      show_banner = false;
      buffer_editor = "hx";
      completions = {
        case_sensitive = false;
        quick = true;
        partial = true;
        algorithm = "fuzzy";
      };
      history = {
        file_format = "sqlite";
        max_size = 1000000;
        sync_on_enter = true;
        isolation = false;
      };
    };
    extraConfig = ''
      def nos [...args] {
        nh os switch ...$args
      }

      def nwhich [flag: string] {
        let result = (which $flag | get path);
        if ($result | is-empty) { $"($flag) not found" } else { $result | first | path expand }
      }
      fortune
    '';
  };

  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
  };
}
