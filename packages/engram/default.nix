{
  lib,
  stdenvNoCC,
  fetchurl,
}:

# Engram — persistent memory for coding agents (SQLite + FTS5 behind a CLI,
# HTTP API and MCP server). Pi talks to it through the `gentle-engram` package
# (see common/pi.nix); Claude Code through engram's own plugin + MCP server.
#
# Prebuilt release binary: it is a static Go build (pure-Go modernc SQLite),
# and building from source needs a newer Go toolchain than our nixpkgs pins.
#
# Keep in lockstep with `gentle-engram` in common/pi.nix — the Pi package
# refuses to talk to an engram whose runtime contract it doesn't know.
stdenvNoCC.mkDerivation rec {
  pname = "engram";
  version = "3.7.1";

  src = fetchurl {
    url = "https://github.com/Gentleman-Programming/engram/releases/download/v${version}/engram_${version}_linux_amd64.tar.gz";
    hash = "sha256-vBrO9iXxaSOyulSODJEZlrMNZcfHzxXpSey8WBNrEns=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 engram $out/bin/engram
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/engram version | grep -q ${version}
  '';

  meta = {
    description = "Persistent memory for AI coding agents";
    homepage = "https://github.com/Gentleman-Programming/engram";
    license = lib.licenses.mit;
    mainProgram = "engram";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
