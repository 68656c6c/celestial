{
  lib,
  inputs,
  ...
}:

let
  certsDir = inputs.trusted-certificates;
  certFiles = lib.filter (name: lib.hasSuffix ".pem" name || lib.hasSuffix ".crt" name) (
    builtins.attrNames (builtins.readDir certsDir)
  );
in

{
  security.pki.certificateFiles = map (file: "${certsDir}/${file}") certFiles;
}
