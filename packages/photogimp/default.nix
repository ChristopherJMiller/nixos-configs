{
  lib,
  fetchFromGitHub,
  writeShellScriptBin,
  runCommandLocal,
  gimp-with-plugins,
}:

# PhotoGIMP is not a fork of GIMP — it is purely a set of config files (theme,
# keyboard shortcuts mimicking Photoshop, tool options, splash screen) that
# overlay a normal GIMP 3 install. Upstream expects you to drop its
# `.config/GIMP/3.0` into your home dir. Since GIMP writes into its config
# directory at runtime, we can't point it straight at the read-only Nix store;
# instead the launcher seeds a writable per-user copy on each run (cp -n keeps
# any edits you've made, while newer PhotoGIMP files still get added on update)
# and steers GIMP at it via GIMP3_DIRECTORY.
let
  version = "3.1";

  src = fetchFromGitHub {
    owner = "Diolinux";
    repo = "PhotoGimp";
    rev = version;
    hash = "sha256-524lsDRmahWXXP9/cfk2ia+7K6xNFTdoYXO8UUsLP/o=";
  };

  launcher = writeShellScriptBin "photogimp" ''
    cfg="''${XDG_CONFIG_HOME:-$HOME/.config}/PhotoGIMP"
    mkdir -p "$cfg"
    cp -rn --no-preserve=mode,ownership ${src}/.config/GIMP/3.0/. "$cfg/" 2>/dev/null || true
    export GIMP3_DIRECTORY="$cfg"
    exec ${gimp-with-plugins}/bin/gimp "$@"
  '';
in
runCommandLocal "photogimp-${version}"
  {
    inherit version;
    passthru = { inherit src launcher; };
    meta = {
      description = "GIMP 3 patched to mimic Adobe Photoshop's UI, shortcuts, and defaults";
      homepage = "https://github.com/Diolinux/PhotoGimp";
      license = lib.licenses.gpl3Plus;
      mainProgram = "photogimp";
      platforms = gimp-with-plugins.meta.platforms or lib.platforms.linux;
    };
  }
  ''
    mkdir -p $out/bin $out/share/applications $out/share/icons
    ln -s ${launcher}/bin/photogimp $out/bin/photogimp

    cp -r ${src}/.local/share/icons/. $out/share/icons/

    cat > $out/share/applications/photogimp.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=PhotoGIMP
    GenericName=Image Editor
    Comment=GIMP configured to mimic Adobe Photoshop
    Exec=${launcher}/bin/photogimp %U
    Icon=photogimp
    Terminal=false
    StartupNotify=true
    Categories=Graphics;2DGraphics;RasterGraphics;GTK;
    MimeType=image/png;image/jpeg;image/gif;image/x-xcf;image/tiff;image/bmp;
    EOF
  ''
