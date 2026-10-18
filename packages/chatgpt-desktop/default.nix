{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
  buildFHSEnv,
  writeShellScript,
  tpm2-tss,
  libusb1,
  xz,
  git,
}:

# OpenAI's official Linux preview of the ChatGPT desktop app (ChatGPT, Work,
# Codex), from their apt repo (https://learn.chatgpt.com/docs/linux/linux-app).
# The .deb is pinned in ./source.json; bump it with
# packages/update-desktop-debs.sh (`nixuc`). Runs unmodified in an FHS env,
# like packages/claude-desktop.
let
  source = lib.importJSON ./source.json;
  inherit (source) version;

  unwrapped = stdenvNoCC.mkDerivation {
    pname = "chatgpt-desktop-unwrapped";
    inherit version;

    src = fetchurl { inherit (source) url sha256; };

    nativeBuildInputs = [ dpkg ];
    unpackPhase = "dpkg-deb --fsys-tarfile $src | tar -x --no-same-permissions --no-same-owner";

    # Prebuilt Chromium-based app; it runs in the FHS env, so leave the ELFs alone.
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;

    installPhase = ''
      mkdir -p $out
      cp -a usr/lib usr/share $out/
    '';
  };
in
buildFHSEnv {
  pname = "chatgpt";
  inherit version;

  # Extras beyond the shared Electron set, from the .deb's Depends/Recommends.
  targetPkgs =
    pkgs:
    (import ../electron-fhs-libs.nix pkgs)
    ++ [
      tpm2-tss
      libusb1
      xz
      git
    ];

  # Host LD_LIBRARY_PATH entries are built against the host glibc and break
  # inside the FHS env, so drop them (see packages/claude-desktop).
  runScript = writeShellScript "chatgpt" ''
    unset LD_LIBRARY_PATH
    exec ${unwrapped}/lib/chatgpt/ChatGPT "$@"
  '';

  # The upstream entry also claims http/https; drop those so ChatGPT never
  # becomes a candidate default browser.
  extraInstallCommands = ''
    mkdir -p $out/share/applications $out/share/pixmaps
    sed -e 's|^Exec=chatgpt|Exec='"$out"'/bin/chatgpt|' \
        -e 's|x-scheme-handler/http;x-scheme-handler/https;||' \
      ${unwrapped}/share/applications/chatgpt.desktop \
      > $out/share/applications/chatgpt.desktop
    cp ${unwrapped}/share/pixmaps/chatgpt.png $out/share/pixmaps/
  '';

  passthru = { inherit unwrapped; };

  meta = {
    description = "ChatGPT desktop app (official Linux preview)";
    homepage = "https://chatgpt.com";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "chatgpt";
  };
}
