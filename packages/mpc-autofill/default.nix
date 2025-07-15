{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zlib,
  makeDesktopItem,
}:

let
  desktopItem = makeDesktopItem {
    name = "mpc-autofill";
    exec = "mpc-autofill";
    desktopName = "MPC Autofill";
    comment = "Desktop tool for automating MakePlayingCards.com orders";
    categories = [
      "Utility"
      "Office"
    ];
    terminal = true;
  };
in
stdenv.mkDerivation rec {
  pname = "mpc-autofill";
  version = "4.5.2";

  src = fetchurl {
    url = "https://github.com/chilli-axe/mpc-autofill/releases/download/v${version}/autofill-linux";
    sha256 = "sha256-m8qcw1n2h7w1ItU04Eu6vRUpQMSmkuP+4KCIXu1KbEQ=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    zlib
  ];

  dontUnpack = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp $src $out/bin/mpc-autofill
    chmod +x $out/bin/mpc-autofill

    # Install desktop entry
    mkdir -p $out/share/applications
    cp ${desktopItem}/share/applications/* $out/share/applications/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Desktop tool for automating MakePlayingCards.com orders";
    longDescription = ''
      A desktop tool that ingests XML files and automates the process of:
      - Downloading images from Google Drive
      - Using Selenium browser automation to populate MakePlayingCards.com orders
      - Supports various command-line options for customization
    '';
    homepage = "https://github.com/chilli-axe/mpc-autofill";
    license = licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
