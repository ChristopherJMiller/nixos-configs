{
  lib,
  stdenvNoCC,
  qt6,
}:

# Plasma 6 panel widget: app launchers that collapse to one icon when the
# panel is crowded and hide when no wide screen is connected. Placed on the
# panel by common/plasma.nix (`rightLaunchers`).
stdenvNoCC.mkDerivation {
  pname = "plasma-widelaunchers";
  version = "1.0";

  src = ./.;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/share/plasma/plasmoids
    cp -r package $out/share/plasma/plasmoids/xyz.chrismiller.widelaunchers
  '';

  doCheck = true;
  nativeCheckInputs = [ qt6.qtdeclarative ];
  dontWrapQtApps = true; # QML package, nothing to wrap
  checkPhase = ''
    QT_QPA_PLATFORM=offscreen QML_IMPORT_PATH=${qt6.qtdeclarative}/${qt6.qtbase.qtQmlPrefix} \
      qmltestrunner -input tests
  '';

  meta = {
    description = "Plasma panel launchers that collapse or hide by available width";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
