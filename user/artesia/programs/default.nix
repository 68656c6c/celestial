{
  lib,
  ...
}:

let
  isNixFile = name: value: value == "regular" && lib.hasSuffix ".nix" name && name != "default.nix";
  isNixDir = name: value: value == "directory" && builtins.pathExists (./. + "/${name}/default.nix");

  fileImports = lib.mapAttrsToList (name: _: ./. + "/${name}") (
    lib.filterAttrs isNixFile (builtins.readDir ./.)
  );

  dirImports = lib.mapAttrsToList (name: _: ./. + "/${name}") (
    lib.filterAttrs isNixDir (builtins.readDir ./.)
  );
in
{
  imports = fileImports ++ dirImports;
}
