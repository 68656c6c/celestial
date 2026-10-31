{
  lib,
  appimageTools,
  fetchurl,
}:

appimageTools.wrapType2 rec {
  pname = "zen";
  version = "1.24b";

  src = fetchurl {
    url = "https://github.com/zen-browser/desktop/releases/download/${version}/${pname}-x86_64.AppImage";
    sha256 = "sha256-xesF42xf/cLYwgtE5HA/JeDyhhGOWbqQP4LSEhtKfic=";
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
    description = "Welcome to a calmer internet";
    homepage = "https://github.com/zen-browser/desktop";
    license = licenses.mpl20;
    platforms = platforms.linux;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
