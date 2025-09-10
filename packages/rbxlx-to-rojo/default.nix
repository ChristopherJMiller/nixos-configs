{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  gtk3,
  glib,
  cairo,
  pango,
  gdk-pixbuf,
  atk,
  wrapGAppsHook,
  gsettings-desktop-schemas,
  makeDesktopItem,
  copyDesktopItems,
}:

rustPlatform.buildRustPackage rec {
  pname = "rbxlx-to-rojo";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "rojo-rbx";
    repo = "rbxlx-to-rojo";
    rev = "aa3ef0e8f1451750ad70c619ce2880b5704a3de1";
    sha256 = "sha256-hgvpR+Ibpcy3Z9boo18pr/r8ZKNTqVYmnSxd0yZ/U5U=";
  };

  cargoHash = "sha256-3jSDmj9mNIiwxPviLlL3nScPwFAxuR8dilmY0jfDz+Y=";

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook
    copyDesktopItems
  ];

  buildInputs = [
    openssl
    gtk3
    glib
    cairo
    pango
    gdk-pixbuf
    atk
    gsettings-desktop-schemas
  ];

  # Build with all features as required
  buildNoDefaultFeatures = false;
  buildFeatures = [ ];
  cargoBuildFlags = [ "--all-features" ];

  desktopItems = [
    (makeDesktopItem {
      name = "rbxlx-to-rojo";
      exec = "rbxlx-to-rojo";
      desktopName = "Rbxlx to Rojo";
      comment = "Convert Roblox place and model files to Rojo projects";
      categories = [ "Development" "Utility" ];
      terminal = false;
    })
  ];

  meta = with lib; {
    description = "Converts Roblox place and model files to Rojo projects";
    homepage = "https://github.com/rojo-rbx/rbxlx-to-rojo";
    license = licenses.mpl20;
    maintainers = [ ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}