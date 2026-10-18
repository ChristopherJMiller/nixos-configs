{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
  buildFHSEnv,
  writeShellScript,
  runCommandLocal,
  OVMF,
  qemu_kvm,
  virtiofsd,
  bubblewrap,
  socat,
  openssh,
}:

# Anthropic's official Linux build of Claude Desktop, from their apt repo
# (https://code.claude.com/docs/en/desktop-linux). The .deb is pinned in
# ./source.json; bump it with packages/update-desktop-debs.sh (`nixuc`).
#
# It runs unmodified inside an FHS env so that Cowork finds its VM tooling
# where a Debian install would have it. Probed by the app (strings in
# app.asar's compiled chunk, 2.42304.0):
#   qemu-system-x86_64             — looked up on PATH
#   /usr/share/OVMF/OVMF_CODE_4M.fd, then /usr/share/OVMF/OVMF_CODE.fd
#   /usr/libexec/virtiofsd, then /usr/bin/virtiofsd
# Nixpkgs' OVMF is the 4 MiB-flash build (CODE 3653632 B + VARS 540672 B),
# i.e. the same layout as Debian's OVMF_CODE_4M.fd. The host side (kvm group,
# vhost_vsock) is common/cowork.nix. Set COWORK_VM_DEBUG=1 to debug the VM.
let
  source = lib.importJSON ./source.json;
  inherit (source) version;

  unwrapped = stdenvNoCC.mkDerivation {
    pname = "claude-desktop-unwrapped";
    inherit version;

    src = fetchurl { inherit (source) url sha256; };

    nativeBuildInputs = [ dpkg ];
    # Plain extract: the setuid bit on chrome-sandbox can't be set in the
    # sandbox (and isn't needed — Chromium uses user namespaces instead).
    unpackPhase = "dpkg-deb --fsys-tarfile $src | tar -x --no-same-permissions --no-same-owner";

    # Prebuilt Electron app; it runs in the FHS env, so leave the ELFs alone.
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;

    installPhase = ''
      mkdir -p $out
      cp -a usr/lib usr/share $out/
    '';
  };

  debianLayout = runCommandLocal "claude-desktop-debian-layout" { } ''
    mkdir -p $out/share/OVMF $out/libexec
    for v in CODE VARS; do
      ln -s ${OVMF.fd}/FV/OVMF_$v.fd $out/share/OVMF/OVMF_''${v}_4M.fd
      ln -s ${OVMF.fd}/FV/OVMF_$v.fd $out/share/OVMF/OVMF_$v.fd
    done
    ln -s ${virtiofsd}/bin/virtiofsd $out/libexec/virtiofsd
  '';
in
buildFHSEnv {
  pname = "claude-desktop";
  inherit version;

  targetPkgs =
    pkgs:
    (import ../electron-fhs-libs.nix pkgs)
    ++ [
      qemu_kvm
      virtiofsd
      bubblewrap
      socat
      openssh
      debianLayout
    ];

  # Host LD_LIBRARY_PATH entries (e.g. a newer alsa-lib) are built against
  # the host glibc and break inside the FHS env, so drop them.
  runScript = writeShellScript "claude-desktop" ''
    unset LD_LIBRARY_PATH
    exec ${unwrapped}/lib/claude-desktop/claude-desktop "$@"
  '';

  extraInstallCommands = ''
    mkdir -p $out/share/applications $out/share/mime/packages
    sed 's|^Exec=claude-desktop|Exec='"$out"'/bin/claude-desktop|' \
      ${unwrapped}/share/applications/com.anthropic.Claude.desktop \
      > $out/share/applications/com.anthropic.Claude.desktop
    cp -r ${unwrapped}/share/icons $out/share/
    cp ${unwrapped}/lib/claude-desktop/resources/linux-mime/com.anthropic.Claude.xml \
      $out/share/mime/packages/
  '';

  passthru = { inherit unwrapped debianLayout; };

  meta = {
    description = "Claude Desktop (official Linux build) with Cowork";
    homepage = "https://claude.ai";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "claude-desktop";
  };
}
