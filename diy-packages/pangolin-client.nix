{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  wrapGAppsHook3,
  gtk3,
  webkitgtk_4_1,
  libsoup_3,
  libx11,
}:

stdenv.mkDerivation rec {
  pname = "pangolin-client";
  version = "0.2.0";

  src = fetchurl {
    url = "https://github.com/fosrl/windows-linux/releases/download/linux-${version}/${pname}-amd64-${version}.tar.gz";
    sha256 = "sha256-CvLaiaFyS5GrQ9nDyWkRx2l3sXO3Cl2mDhHb6UuAIxU=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    gtk3
    webkitgtk_4_1
    libsoup_3
    libx11
  ];

  dontConfigure = true;
  dontBuild = true;

  # The archive's install.sh writes to /etc and /usr and starts the service;
  # the service itself is declared in diy-modules/pangolin_client.nix.
  installPhase = ''
    runHook preInstall
    install -Dm755 bin/pangolin-client -t $out/bin
    cp -r share $out/share
    install -Dm644 etc/xdg/autostart/pangolin-client-autostart.desktop -t $out/etc/xdg/autostart
    runHook postInstall
  '';

  meta = with lib; {
    description = "Pangolin client with a tray menu and settings window";
    homepage = "https://github.com/fosrl/windows-linux";
    license = licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "pangolin-client";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
