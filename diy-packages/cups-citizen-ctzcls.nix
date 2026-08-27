{
  lib,
  stdenv,
  fetchurl,
  cups,
}:

stdenv.mkDerivation {
  pname = "cups-citizen-ctzcls";
  version = "1.5";

  src = fetchurl {
    url = "https://www.citizen-systems.co.jp/cms/c-s/en/printer/download/driver-cups-source/cups-ctzcls.tar.gz";
    hash = "sha256-G7sEIibQbK5xWvv2WLCbhWrEJ1teIQeNToRtTngdQo8=";
  };

  buildInputs = [ cups ];

  unpackPhase = ''
    runHook preUnpack
    mkdir -p $TMPDIR/ctzcls
    tar xzf $src -C $TMPDIR/ctzcls
    sourceRoot=$TMPDIR/ctzcls
    runHook postUnpack
  '';

  buildPhase = ''
    runHook preBuild
    $CC $CFLAGS -fPIC -o rastertocls rastertocls.c -lcupsimage -lcups $LDFLAGS
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 ctzcls.ppd $out/share/cups/model/ctzcls.ppd
    install -Dm755 rastertocls $out/lib/cups/filter/rastertocls
    runHook postInstall
  '';

  meta = with lib; {
    description = "CUPS driver for Citizen CL-S521 and similar label printers";
    homepage = "https://www.citizen-systems.co.jp/en/printer/download/driver-cups-source/";
    license = licenses.gpl2;
    platforms = platforms.linux;
    sourceProvenance = with sourceTypes; [ fromSource ];
  };
}
