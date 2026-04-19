# Sunshine pre-release with PipeWire/xdg-desktop-portal screen capture support.
# Based on nixpkgs sunshine package, pinned to v2026.415.34134.
{ pkgs }:

let
  version = "2026.415.34134";

  src = pkgs.fetchFromGitHub {
    owner = "LizardByte";
    repo = "Sunshine";
    tag = "v${version}";
    hash = "sha256-nwX763aUcsE/FsEvXOJqEzVftasULC+fFZ6PpxPI33E=";
    fetchSubmodules = true;
  };

  # Pre-fetch ffmpeg static binaries (can't download in sandbox).
  # Tag v2026.323.141148 matches the build-deps submodule commit.
  ffmpegBinaries = pkgs.fetchurl {
    url = "https://github.com/LizardByte/build-deps/releases/download/v2026.323.141148/Linux-x86_64-ffmpeg.tar.gz";
    hash = "sha256-ZjGXBqlNFgdJLm68UQYJGPzlEZfVicrDE96MUyFDoYQ=";
  };
in
pkgs.sunshine.overrideAttrs (oldAttrs: {
  inherit version src;

  ui = pkgs.buildNpmPackage {
    inherit src version;
    pname = "sunshine-ui";
    npmDepsHash = "sha256-Wrcow9f/z6tiJc2Y1zsXjfoQMmpTi0vjp56Mhmyj8sM=";

    postPatch = ''
      cp ${./package-lock.json} ./package-lock.json
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -a . "$out"/
      runHook postInstall
    '';
  };

  # Updated postPatch for new version's file layout
  postPatch =
    # remove upstream dependency on systemd and udev
    ''
      substituteInPlace cmake/packaging/linux.cmake \
        --replace-fail 'find_package(Systemd)' "" \
        --replace-fail 'find_package(Udev)' ""
    ''
    # Use system Boost (1.87) instead of requiring exact 1.89 (which triggers FetchContent)
    + ''
      substituteInPlace cmake/dependencies/Boost_Sunshine.cmake \
        --replace-fail 'find_package(Boost CONFIG ''${BOOST_VERSION} EXACT' 'find_package(Boost CONFIG'
    ''
    # Force ScreenCast-only portal mode (skip RemoteDesktop portal).
    # RemoteDesktop auto-grants only the primary display; ScreenCast shows a
    # picker dialog that lets the user select the virtual display.
    + ''
      substituteInPlace src/platform/linux/portalgrab.cpp \
        --replace-fail 'bool use_screencast_only = !try_remote_desktop_session(loop, &session_path, session_token);' \
                       'bool use_screencast_only = true;'
    ''
    # Fix NVENC SDK 13.0 compatibility (nv-codec-headers 12.1.x)
    # Based on upstream PR LizardByte/Sunshine#4892
    + ''
      patch -p1 < ${./nvenc-sdk-13.patch}
    ''
    # Pre-extract ffmpeg binaries so cmake doesn't try to download them.
    # Tarball contains ffmpeg/ dir, extract to $NIX_BUILD_TOP so it lands at /build/ffmpeg/
    + ''
      tar -xzf ${ffmpegBinaries} -C "$NIX_BUILD_TOP"
    ''
    # don't look for npm since we build webui separately
    + ''
      substituteInPlace cmake/targets/common.cmake \
        --replace-fail 'find_program(NPM npm REQUIRED)' ""

      substituteInPlace packaging/linux/dev.lizardbyte.app.Sunshine.desktop \
        --subst-var-by PROJECT_NAME 'Sunshine' \
        --subst-var-by PROJECT_FQDN 'dev.lizardbyte.app.Sunshine' \
        --subst-var-by PROJECT_DESCRIPTION 'Self-hosted game stream host for Moonlight' \
        --subst-var-by SUNSHINE_DESKTOP_ICON 'sunshine' \
        --subst-var-by CMAKE_INSTALL_FULL_DATAROOTDIR "$out/share" \
        --replace-fail '/usr/bin/env systemctl start --u app-dev.lizardbyte.app.Sunshine' 'sunshine'

      substituteInPlace packaging/linux/app-dev.lizardbyte.app.Sunshine.service.in \
        --subst-var-by PROJECT_DESCRIPTION 'Self-hosted game stream host for Moonlight' \
        --replace-fail '@SUNSHINE_SERVICE_START_COMMAND@' "ExecStart=$out/bin/sunshine" \
        --replace-fail '@SUNSHINE_SERVICE_STOP_COMMAND@' "" \
        --replace-fail '/bin/sleep' '${pkgs.lib.getExe' pkgs.coreutils "sleep"}'
    '';

  preConfigure = (oldAttrs.preConfigure or "") + ''
    cmakeFlagsArray+=("-DFFMPEG_PREPARED_BINARIES=$NIX_BUILD_TOP/ffmpeg")
  '';

  # New build deps in this version:
  # - glad (OpenGL loader generator) needs python3 with jinja2 and setuptools
  # - vulkan video encoding needs vulkan-loader, vulkan-headers, and glslc (shaderc)
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
    (pkgs.python3.withPackages (ps: [ ps.jinja2 ps.setuptools ]))
    pkgs.shaderc  # provides glslc
  ];

  buildInputs = (oldAttrs.buildInputs or [ ]) ++ [
    pkgs.vulkan-loader
    pkgs.vulkan-headers
    pkgs.pipewire
  ];

  env = (oldAttrs.env or { }) // {
    BUILD_VERSION = version;
  };
})
