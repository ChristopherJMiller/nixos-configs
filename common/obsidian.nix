{ pkgs, ... }:

let
  # Install upstream release assets, not the unbuilt TypeScript sources.
  version = "0.5.25";
  asset =
    name: hash:
    pkgs.fetchurl {
      url = "https://github.com/remotely-save/remotely-save/releases/download/${version}/${name}";
      inherit hash;
    };
  remotelySave = pkgs.runCommand "obsidian-remotely-save-${version}" { } ''
    mkdir -p "$out"
    cp ${asset "main.js" "sha256-s6+9J/FRiLl4RhjJWGB4abqkNNwKvPByd0+ZNiwR+gQ="} "$out/main.js"
    cp ${asset "manifest.json" "sha256-cdnAthYAPzppaIDnqogpblsxVVdX6TOhLSkAuWxMqpA="} "$out/manifest.json"
    cp ${asset "styles.css" "sha256-h1hOfVOMpYxSevuyYlsJ6igryue/eEt8zjPKkung37M="} "$out/styles.css"
  '';
in
{
  programs.obsidian = {
    enable = true;
    # Electron 41+ otherwise falls back to the shared electron executable's
    # name, so Plasma cannot associate Wayland windows with obsidian.desktop.
    package = pkgs.obsidian.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
        pkgs.asar
        pkgs.jq
      ];
      postPatch = (old.postPatch or "") + ''
        asar extract resources/app.asar obsidian-app
        jq '.desktopName = "obsidian"' obsidian-app/package.json > obsidian-package.json
        mv obsidian-package.json obsidian-app/package.json
        asar pack obsidian-app resources/app.asar
        rm -r obsidian-app
      '';
      postInstall = (old.postInstall or "") + ''
        sed -i 's/^StartupWMClass=.*/StartupWMClass=obsidian/' "$out/share/applications/obsidian.desktop"
      '';
    });
    vaults.ObsidianVault = {
      target = "ObsidianVault";
      settings.communityPlugins = [ { pkg = remotelySave; } ];
      # Keep data.json writable and outside the Nix store: configure Fastmail
      # WebDAV and its app password in Remotely Save's settings on each host.
    };
  };
}
