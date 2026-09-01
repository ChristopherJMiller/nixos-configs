{
  lib,
  stdenvNoCC,
  libgourou,
  zip,
}:

# A Calibre file-type plugin that fulfills Adobe ``.acsm`` tokens and strips
# ADEPT DRM on import by shelling out to the native ``libgourou`` utilities.
#
# The Python source in ./plugin ships with ``@name@`` placeholders where the
# libgourou binary paths go; we substitute the concrete /nix/store paths in
# here so the plugin has zero runtime discovery to do (and, crucially, no
# bundled ``oscrypto`` — the thing that makes the usual DeACSM plugin fail on
# NixOS with OpenSSL 3).
#
# Output: $out/share/calibre/plugins/ACSM_Input_libgourou.zip — installed into
# Calibre with ``calibre-customize -a`` from a home-manager activation script
# (see hosts/celebi/home.nix). passthru.pluginName is the display name that
# script removes/re-adds so updates take effect.

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "calibre-acsm-plugin";
  version = "1.0.0";

  src = ./plugin;

  nativeBuildInputs = [ zip ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    cp __init__.py plugin_init.py
    substituteInPlace plugin_init.py \
      --replace-fail '@acsmdownloader@' '${libgourou}/bin/acsmdownloader' \
      --replace-fail '@adept_remove@'   '${libgourou}/bin/adept_remove' \
      --replace-fail '@adept_activate@' '${libgourou}/bin/adept_activate'

    mkdir plugin_root
    cp plugin_init.py plugin_root/__init__.py

    # Reproducible zip: fixed mtime (zip's floor is 1980) and no extra attrs.
    touch -d "@''${SOURCE_DATE_EPOCH:-315532800}" plugin_root/__init__.py
    ( cd plugin_root && zip -X -q -r ../ACSM_Input_libgourou.zip . )

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 ACSM_Input_libgourou.zip \
      "$out/share/calibre/plugins/ACSM_Input_libgourou.zip"
    runHook postInstall
  '';

  passthru = {
    # Native ADEPT tools the plugin drives — handy to also drop on $PATH.
    adeptTools = libgourou;
    # Display name Calibre registers the plugin under; the activation script
    # removes this before re-adding so a rebuilt zip actually replaces the old.
    pluginName = "ACSM Input (libgourou)";
    pluginZip = "share/calibre/plugins/ACSM_Input_libgourou.zip";
  };

  meta = {
    description = "Calibre plugin: fulfill Adobe ACSM + strip ADEPT DRM via native libgourou (NixOS-friendly)";
    homepage = "https://forge.soutade.fr/soutade/libgourou";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    maintainers = [ ];
  };
})
