{
  lib,
  stdenv,
  fetchurl,
  writeText,
  wrapGAppsHook3,
  autoPatchelfHook,
  patchelfUnstable,
  alsa-lib,
  gtk3,
  wrapThunderbird,
}:

# Betterbird (a patched Thunderbird ESR) was dropped from nixpkgs, so this
# repackages the upstream Linux binary the same way nixpkgs builds
# thunderbird-bin, then runs it through the regular Thunderbird wrapper.
# Betterbird keeps Thunderbird's profile location (~/.thunderbird), so
# home-manager's programs.thunderbird configuration applies unchanged.
let
  version = "153.7.0esr-bb13";

  policies = writeText "betterbird-policies.json" (
    builtins.toJSON { policies.DisableAppUpdate = true; }
  );

  unwrapped = stdenv.mkDerivation {
    pname = "betterbird-bin";
    inherit version;

    # Older releases move to LinuxArchive/Previous/ once superseded.
    src = fetchurl {
      url = "https://www.betterbird.eu/downloads/LinuxArchive/betterbird-${version}.en-US.linux-x86_64.tar.xz";
      hash = "sha256-FF0Ho0/AW7pQpBstk7xXaS4GkOV+b9nKQTwvy2QsOTQ=";
    };

    nativeBuildInputs = [
      wrapGAppsHook3
      autoPatchelfHook
      patchelfUnstable
    ];
    buildInputs = [ alsa-lib ];

    # Thunderbird uses "relrhack" to manually process relocations from a fixed offset
    patchelfFlags = [ "--no-clobber-old-sections" ];

    postPatch = ''
      echo 'pref("app.update.auto", "false");' >> defaults/pref/channel-prefs.js
    '';

    # wrapThunderbird looks for the application in $out/lib/thunderbird.
    installPhase = ''
      runHook preInstall

      mkdir -p "$out/lib/thunderbird" "$out/bin"
      cp -r * "$out/lib/thunderbird"
      ln -s "$out/lib/thunderbird/betterbird" "$out/bin/"

      gappsWrapperArgs+=(--argv0 "$out/bin/.betterbird-wrapped")

      mkdir -p "$out/lib/thunderbird/distribution"
      ln -s ${policies} "$out/lib/thunderbird/distribution/policies.json"

      runHook postInstall
    '';

    passthru = {
      applicationName = "Betterbird";
      binaryName = "betterbird";
      gssSupport = true;
      inherit gtk3;
    };

    meta = {
      description = "Fine-tuned version of Mozilla Thunderbird (binary package)";
      homepage = "https://www.betterbird.eu/";
      license = lib.licenses.mpl20;
      mainProgram = "betterbird";
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      platforms = [ "x86_64-linux" ];
    };
  };
in
wrapThunderbird unwrapped { pname = "betterbird"; }
