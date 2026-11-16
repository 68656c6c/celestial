{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.vscode;

  # Written by scripts/update-vscode-extensions.sh, daily in CI.
  pins = lib.importJSON ./vscode_marketplace.lock.json;

  # The whole Marketplace, releases that run on the VS Code installed here.
  # Loading it costs seconds of every evaluation, which is what the pins are
  # for: it is only read for an id that has no pin yet, and by the updater.
  catalogue =
    (pkgs.nix-vscode-extensions.forVSCodeVersion cfg.package.version).vscode-marketplace-release;
  fromCatalogue = id: lib.attrByPath (builtins.match "([^.]+)\\.(.+)" id) null catalogue;

  # The catalogue's own builder, so a pinned extension is the same derivation,
  # nixpkgs' patches included.
  mkExtension = import "${inputs.nix-vscode-extensions}/nix/mkExtension.nix" {
    inherit pkgs;
    pkgsWithFixes = pkgs;
    inherit (pkgs.stdenv.hostPlatform) system;
  };
  fromPin =
    pin:
    mkExtension {
      mktplcRef = {
        inherit (pin)
          publisher
          name
          version
          hash
          ;
      };
      vsix = pkgs.fetchurl {
        inherit (pin) url hash;
        name = pin.file;
      };
      inherit (pin) engineVersion platform isRelease;
    };

  # The catalogue's own rule for a release that runs on this VS Code. A pin
  # can fall behind it when nixpkgs is rolled back and the pin file is not.
  inherit (import "${inputs.nix-vscode-extensions}/nix/semver.nix" { inherit lib; }) compareSemVer;
  runsHere =
    engine:
    if lib.hasPrefix "^" engine then
      compareSemVer cfg.package.version (lib.removePrefix "^" engine) >= 0
    else
      compareSemVer cfg.package.version engine == 0;

  extension =
    id:
    if pins ? ${id} then
      lib.warnIfNot (runsHere pins.${id}.engineVersion)
        "VS Code extension ${id} is pinned to ${pins.${id}.version}, which needs VS Code ${pins.${id}.engineVersion} and ${cfg.package.version} is installed; run scripts/update-vscode-extensions.sh"
        (fromPin pins.${id})
    else
      let
        found = fromCatalogue id;
      in
      if found == null then
        throw "VS Code extension ${id}: no release on the Marketplace runs on VS Code ${cfg.package.version}"
      else
        lib.warn "VS Code extension ${id} is not pinned yet, evaluation is slower until scripts/update-vscode-extensions.sh has run" found;

  # An extension the catalogue no longer offers for this VS Code keeps its pin.
  pinOf =
    id:
    let
      found = fromCatalogue id;
    in
    if found != null then
      {
        inherit (found.passthru.mktplcRef)
          publisher
          name
          version
          hash
          ;
        inherit (found.passthru) engineVersion platform isRelease;
        inherit (found.passthru.vsix) url;
        file = found.passthru.vsix.name;
      }
    else
      pins.${id}
        or (throw "VS Code extension ${id}: no release on the Marketplace runs on VS Code ${cfg.package.version}");
in

{
  options.programs.vscode.marketplaceExtensions = lib.mkOption {
    type = lib.types.listOf (lib.types.strMatching "[a-z0-9][a-z0-9-]*\\.[a-z0-9][a-z0-9._-]*");
    default = [ ];
    example = [ "jnoortheen.nix-ide" ];
    description = "Extensions by Marketplace id, <publisher>.<name> in lowercase.";
  };

  config = {
    programs.vscode.extensions = map extension cfg.marketplaceExtensions;

    # One extension per line, so a bump is a one-line diff.
    system.build.vscodeMarketplacePins =
      "{\n"
      + lib.concatMapStringsSep ",\n" (id: "  ${builtins.toJSON id}: ${builtins.toJSON (pinOf id)}") (
        lib.naturalSort (lib.unique cfg.marketplaceExtensions)
      )
      + "\n}\n";
  };
}
