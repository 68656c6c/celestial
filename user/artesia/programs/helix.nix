{
  pkgs,
  lib,
  osConfig,
  ...
}:

{
  programs.helix = {
    enable = true;
    settings = {
      theme = lib.mkIf osConfig.programs.noctalia.enable "noctalia";
      editor.cursor-shape = {
        normal = "block";
        insert = "bar";
        select = "underline";
      };
    };
    defaultEditor = true;
    languages = {
      language = [
        {
          name = "nix";
          auto-format = true;
          formatter.command = lib.getExe pkgs.nixfmt;
          language-servers = [
            "nil"
            "nixd"
          ];
        }
      ];
      language-server = {
        nil.command = lib.getExe pkgs.nil;
        nixd.command = lib.getExe pkgs.nixd;
      };
    };
  };
}
