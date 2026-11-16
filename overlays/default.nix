{ unstable, niri-float-sticky }:
final: prev: {
  # Software not in nixpkgs, available as pkgs.diy.<name>
  diy = import ../diy-packages { pkgs = final; };
  inherit niri-float-sticky;

  # nixpkgs electron cannot find libva, so calls and streams are decoded on the
  # CPU. Drop when NixOS/nixpkgs#569737 reaches the stable channel.
  vesktop = final.symlinkJoin {
    inherit (prev.vesktop) pname version meta;
    paths = [ prev.vesktop ];
    nativeBuildInputs = [ final.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/vesktop \
        --prefix LD_LIBRARY_PATH : ${final.lib.makeLibraryPath [ final.libva ]}
    '';
  };

  # Stable release for everything, unstable for the few that need to move faster
  hyprpicker = unstable.hyprpicker;
  nushell = unstable.nushell;
  atuin = unstable.atuin;
  flameshot = unstable.flameshot;
  noctalia = unstable.noctalia;
  bitwarden-desktop = unstable.bitwarden-desktop;
  opencode = unstable.opencode;
  claude-code = unstable.claude-code;
  pangolin-cli = unstable.pangolin-cli;
  ghostty = unstable.ghostty;
  openmw = unstable.openmw;
}
