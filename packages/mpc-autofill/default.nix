{
  lib,
  python3,
  fetchFromGitHub,
  fetchPypi,
  fetchurl,
  makeDesktopItem,
  makeWrapper,
  chromedriver,
  chromium,
}:

let
  version = "4.5.2";
  
  # PyInstaller extractor
  pyinstxtractor = fetchurl {
    url = "https://raw.githubusercontent.com/extremecoders-re/pyinstxtractor/master/pyinstxtractor.py";
    sha256 = "0n7dkz8ib85wgsrrdsmd8makv7lm17p9lmvlz1wips2rawn7h2p9";
  };

  # Download the release binary to extract client_secrets.json
  releaseBinary = fetchurl {
    url = "https://github.com/chilli-axe/mpc-autofill/releases/download/v${version}/autofill-linux";
    sha256 = "sha256-m8qcw1n2h7w1ItU04Eu6vRUpQMSmkuP+4KCIXu1KbEQ=";
  };
  # Build missing Python packages
  wakepy = python3.pkgs.buildPythonPackage rec {
    pname = "wakepy";
    version = "0.6.0";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-Kdiztf9+a6CIrw07YEDzNjkiiZ+mNhWsBoMH/ERrUWA=";
    };

    build-system = with python3.pkgs; [
      setuptools
    ];

    propagatedBuildInputs = with python3.pkgs; [
      jeepney
      dbus-python
    ];
  };

  sanitize-filename = python3.pkgs.buildPythonPackage rec {
    pname = "sanitize_filename";
    version = "1.2.0";
    pyproject = true;

    src = fetchPypi {
      inherit pname version;
      hash = "sha256-51kz6W1CbjBu74wnDMJMPhlx2HFSiMl3bYAdPY57lBo=";
    };

    build-system = with python3.pkgs; [
      setuptools
    ];
  };

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
python3.pkgs.buildPythonApplication rec {
  pname = "mpc-autofill";
  inherit version;

  src = fetchFromGitHub {
    owner = "chilli-axe";
    repo = "mpc-autofill";
    rev = "v${version}";
    sha256 = "sha256-I7aDA41XEUre29GSsSrD5aX/M+VJ2HPQp4jy+hGFads=";
  };

  sourceRoot = "${src.name}/desktop-tool";

  format = "other"; # Tell Nix this isn't a standard Python package

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    chromedriver
    chromium
  ];

  # Create a python environment with all needed packages
  pythonEnv = python3.withPackages (ps: with ps; [
    attrs
    click
    colorama
    defusedxml
    enlighten
    fpdf2
    google-api-python-client
    google-auth-httplib2
    google-auth-oauthlib
    inquirerpy
    oauth2client
    pillow
    ratelimit
    requests
    selenium
    sanitize-filename
    wakepy
  ]);

  preBuild = ''
    # Extract client_secrets.json from the release binary
    cp ${pyinstxtractor} pyinstxtractor.py
    cp ${releaseBinary} autofill-linux
    chmod +x autofill-linux
    
    # Run the extractor
    ${python3}/bin/python3 pyinstxtractor.py autofill-linux || true
    
    # Copy the extracted client_secrets.json if it exists
    if [ -f autofill-linux_extracted/client_secrets.json ]; then
      cp autofill-linux_extracted/client_secrets.json .
    fi
  '';

  installPhase = ''
    runHook preInstall

    # Copy the application files
    mkdir -p $out/share/mpc-autofill
    cp -r . $out/share/mpc-autofill

    # Create executable wrapper
    mkdir -p $out/bin
    makeWrapper ${pythonEnv}/bin/python3 $out/bin/mpc-autofill \
      --add-flags "$out/share/mpc-autofill/autofill.py" \
      --prefix PATH : "${chromedriver}/bin:${chromium}/bin" \
      --set CHROME_BIN "${chromium}/bin/chromium"

    # Install desktop entry
    mkdir -p $out/share/applications
    cp ${desktopItem}/share/applications/* $out/share/applications/

    runHook postInstall
  '';

  # Patch the logging configuration to use a writable directory
  postPatch = ''
    substituteInPlace src/logging.py \
      --replace 'autofill_crash_log.txt' '/tmp/autofill_crash_log.txt' \
      --replace 'autofill_log.txt' '/tmp/autofill_log.txt'
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
