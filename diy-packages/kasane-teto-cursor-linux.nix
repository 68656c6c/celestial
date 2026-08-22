{ stdenv }:

stdenv.mkDerivation {
  pname = "kasane-teto-cursor-linux";
  version = "1.0";
  src = ./assets/cursors/kasane-teto-cursor-linux.tar.xz;
  sourceRoot = "kasane-teto-cursor-linux";
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/icons/kasane-teto-cursor-linux
    cp -r ./. $out/share/icons/kasane-teto-cursor-linux/
    runHook postInstall
  '';
}