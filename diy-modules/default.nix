{
  lib,
  ...
}:

let
  moduleFiles = lib.filter (
    name: lib.hasSuffix ".nix" name && name != "default.nix"
  ) (builtins.attrNames (builtins.readDir ./.));
in

{
  imports = map (file: ./${file}) moduleFiles;
}
