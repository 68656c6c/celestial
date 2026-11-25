{ unstable, niri-float-sticky }:
final: prev: {
  # Software not in nixpkgs, available as pkgs.diy.<name>
  diy = import ../diy-packages { pkgs = final; };
  inherit niri-float-sticky;

  # nixpkgs electron cannot find libva, so calls and streams are decoded on the
  # CPU. Drop when NixOS/nixpkgs#569737 reaches the stable channel.
  # Unstable because stable's 1.6.5 share picker crashes on current Discord.
  vesktop = final.symlinkJoin {
    inherit (unstable.vesktop) pname version meta;
    paths = [ unstable.vesktop ];
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
  umbriel = unstable.umbriel;
  xdg-desktop-portal-umbriel = unstable.xdg-desktop-portal-umbriel;
  bitwarden-desktop = unstable.bitwarden-desktop;
  opencode = unstable.opencode;
  claude-code = unstable.claude-code;
  pangolin-cli =
    let
      pin = final.lib.importJSON ../diy-packages/pangolin-cli.json;
    in
    unstable.pangolin-cli.overrideAttrs (old: {
      inherit (pin) version vendorHash;
      ldflags = final.lib.filter (flag: !final.lib.hasInfix "NewtVersionOverride" flag) old.ldflags;
      src = final.fetchFromGitHub {
        owner = "fosrl";
        repo = "cli";
        tag = pin.version;
        inherit (pin) hash;
      };
    });
  ghostty = unstable.ghostty;
  openmw = unstable.openmw;
}
