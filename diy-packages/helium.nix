{
  lib,
  appimageTools,
  fetchurl,
}:

appimageTools.wrapType2 rec {
  pname = "helium";
  version = "0.20.1.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/${pname}-${version}-x86_64.AppImage";
    sha256 = "sha256-1LeJsl0KmuEsdmceRE6Khe3Pgo4EGcZ40YxB+xrDAw4=";
  };

  extraInstallCommands =
    let
      contents = appimageTools.extract { inherit pname version src; };
    in
    ''
      install -m 444 -D ${contents}/${pname}.desktop -t $out/share/applications
      cp -r ${contents}/usr/share/icons $out/share
    '';

  meta = with lib; {
    description = "Private, fast and honest web browser";
    homepage = "https://github.com/imputnet/helium-linux";
    license = licenses.gpl3;
    platforms = platforms.linux;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
