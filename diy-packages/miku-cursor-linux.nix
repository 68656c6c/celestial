{ stdenv, fetchFromGitHub }:

stdenv.mkDerivation {
  pname = "miku-cursor-linux";
  version = "1.0";
  src = fetchFromGitHub {
    owner = "supermariofps";
    repo = "hatsune-miku-windows-linux-cursors";
    rev = "1.2.6";
    sha256 = "1lf21iqda2pwh2j07g0sdglrgmfc1ira8rk3nmxi57smrwwy621r";
  };
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/icons/miku-cursor-linux
    cp -r ./miku-cursor-linux/* $out/share/icons/miku-cursor-linux/
    runHook postInstall
  '';
}
