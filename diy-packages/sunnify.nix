{
  lib,
  python3Packages,
  fetchurl,
  ffmpeg,
  qt6,
  makeDesktopItem,
  copyDesktopItems,
}:

python3Packages.buildPythonApplication rec {
  pname = "sunnify";
  version = "2.7.0";
  pyproject = true;

  src = fetchurl {
    url = "https://github.com/sunnypatell/sunnify-spotify-downloader/releases/download/v${version}/sunnify-v${version}-source.tar.gz";
    sha256 = "a097a48790a5068f419e4e59a330e86a7785273166f3b48a122c189e05b9b085";
  };

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    mutagen
    pyqt6
    requests
    yt-dlp
    yt-dlp-ejs
  ];

  nativeBuildInputs = [
    qt6.wrapQtAppsHook
    copyDesktopItems
  ];
  buildInputs = [ qt6.qtwayland ];

  # The GUI only runs under `if __name__ == "__main__"`, so it gets no console script upstream
  postInstall = ''
    cat > $out/bin/sunnify-gui <<EOF
    #!${python3Packages.python.interpreter}
    import runpy
    runpy.run_module("Spotify_Downloader", run_name="__main__")
    EOF
    chmod +x $out/bin/sunnify-gui
    install -Dm444 app.png $out/share/icons/hicolor/512x512/apps/sunnify.png
  '';

  dontWrapQtApps = true;
  preFixup = ''
    makeWrapperArgs+=("''${qtWrapperArgs[@]}" --prefix PATH : ${lib.makeBinPath [ ffmpeg ]})
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "sunnify";
      desktopName = "Sunnify";
      exec = "sunnify-gui";
      icon = "sunnify";
      categories = [
        "Audio"
        "AudioVideo"
      ];
    })
  ];

  pythonImportsCheck = [
    "spotifydown_api"
    "sunnify_cli"
  ];

  meta = {
    description = "Spotify playlist downloader with a PyQt6 GUI and headless CLI";
    homepage = "https://github.com/sunnypatell/sunnify-spotify-downloader";
    license = lib.licenses.unfree;
    mainProgram = "sunnify-gui";
    platforms = lib.platforms.linux;
  };
}
