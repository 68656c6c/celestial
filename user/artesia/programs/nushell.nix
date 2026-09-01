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
      nos = "nh os switch";
    };
    environmentVariables = {
      NIXOS_OZONE_WL = 1;
      NH_OS_FLAKE = "${config.home.homeDirectory}/.dotfiles";
      XCURSOR_SIZE = osConfig.host.cursor.size;
      SSH_AUTH_SOCK = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
      QT_QPA_PLATFORM = "wayland";
      QT_QPA_PLATFORMTHEME = "qt6ct";
      SOPS_AGE_KEY_FILE = "/etc/sops-age/keys";
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
