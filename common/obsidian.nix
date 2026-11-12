{ lib, pkgs, ... }:

let
  # Install upstream release assets, not the unbuilt TypeScript sources.
  releaseAsset =
    repo: version: name: hash:
    pkgs.fetchurl {
      url = "https://github.com/${repo}/releases/download/${version}/${name}";
      inherit hash;
    };

  remotelySaveVersion = "0.5.25";
  remotelySaveAsset = releaseAsset "remotely-save/remotely-save" remotelySaveVersion;
  remotelySave = pkgs.runCommand "obsidian-remotely-save-${remotelySaveVersion}" { } ''
    mkdir -p "$out"
    cp ${remotelySaveAsset "main.js" "sha256-s6+9J/FRiLl4RhjJWGB4abqkNNwKvPByd0+ZNiwR+gQ="} "$out/main.js"
    cp ${remotelySaveAsset "manifest.json" "sha256-cdnAthYAPzppaIDnqogpblsxVVdX6TOhLSkAuWxMqpA="} "$out/manifest.json"
    cp ${remotelySaveAsset "styles.css" "sha256-h1hOfVOMpYxSevuyYlsJ6igryue/eEt8zjPKkung37M="} "$out/styles.css"
  '';

  # Claudian: Claude Code (and Codex) as a chat pane inside the vault.
  claudianVersion = "2.3.40";
  claudianAsset = releaseAsset "YishenTu/claudian" claudianVersion;
  claudian = pkgs.runCommand "obsidian-claudian-${claudianVersion}" { } ''
    mkdir -p "$out"
    cp ${claudianAsset "main.js" "sha256-bP7kSNRj4VDwLuC+JatH1YeYiX4dyjWNlv+f4lNutzE="} "$out/main.js"
    cp ${claudianAsset "manifest.json" "sha256-Iv4zTsaeKogWgLOLjE9qMpXEe/R4Xbd595b16LsA91c="} "$out/manifest.json"
    cp ${claudianAsset "styles.css" "sha256-MYIiY0GhEATjyjqYgONnU9uErtH0XHWZYydwGKUS6PM="} "$out/styles.css"
  '';

  # Catppuccin theme. Its flavor and accent are normally picked through the
  # Style Settings plugin; patch the CSS so Macchiato + Mauve (the system
  # palette) apply by default, while Style Settings classes still override.
  catppuccinVersion = "0.4.52";
  catppuccinAsset = releaseAsset "catppuccin/obsidian" catppuccinVersion;
  catppuccin = pkgs.runCommand "obsidian-catppuccin-${catppuccinVersion}" { } ''
    mkdir -p "$out"
    cp ${catppuccinAsset "manifest.json" "sha256-vjbS8zhQZ1NPowSQZ7GXqKjZBfpk5ypIOHvRWQw4JHk="} "$out/manifest.json"
    sed \
      -e 's/^\.theme-dark\.ctp-macchiato {$/.theme-dark.ctp-macchiato,\nbody.theme-dark:not(.ctp-frappe):not(.ctp-mocha) {/' \
      -e 's/^\.ctp-accent-mauve {$/.ctp-accent-mauve,\nbody:not(.ctp-full-palette):not([class*="ctp-accent-"]) {/' \
      ${catppuccinAsset "theme.css" "sha256-bBMwcArgB39cedlQqQF5pC53eHIp3hJ25cvloEjlcu0="} > "$out/theme.css"
    grep -q 'body.theme-dark:not(.ctp-frappe)' "$out/theme.css"
    grep -q 'body:not(.ctp-full-palette)' "$out/theme.css"
  '';

  # Claudian keeps its settings in the vault and rewrites them at runtime, so
  # these preferences are only seeded when the file does not exist yet.
  claudianSettings = pkgs.writeText "claudian-settings.json" (
    builtins.toJSON {
      userName = "Chris";
      locale = "en";
      permissionMode = "auto";
      model = "haiku";
      effortLevel = "high";
      serviceTier = "default";
      enableAutoTitleGeneration = true;
      keyboardNavigation = {
        scrollUpKey = "w";
        scrollDownKey = "s";
        focusInputKey = "i";
      };
      requireCommandOrControlEnterToSend = false;
      providerConfigs = {
        claude = {
          enabled = true;
          loadUserSettings = true;
          enableChrome = false;
          promptSuggestions = false;
          visibleModels = [ "opus" ];
        };
        codex = {
          enabled = true;
          safeMode = "workspace-write";
          enableUltraEffort = false;
          responseStyle = "pragmatic";
          responseVerbosity = "default";
          reasoningSummary = "detailed";
          visibleModels = [ "gpt-6.1-sol" ];
        };
      };
      settingsProvider = "claude";
      lastSelectedChatModel = {
        providerId = "codex";
        model = "openai-codex/gpt-6.1-sol";
      };
      savedProviderPermissionMode = {
        claude = "auto";
        codex = "yolo";
      };
      enableAutoScroll = true;
      showMessageTimestamps = false;
      deferMathRenderingDuringStreaming = true;
      expandFileEditsByDefault = false;
      chatViewPlacement = "right-sidebar";
      enableZenMode = true;
      enableDualPane = true;
      dualPaneSide = "right";
      restoreTabsOnStartup = true;
      sessionManagerOrganization = "list";
      sessionManagerSort = "last-updated";
      sessionAutoArchiveAfter = "off";
    }
  );
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
      settings = {
        communityPlugins = [
          { pkg = remotelySave; }
          { pkg = claudian; }
        ];
        themes = [{ pkg = catppuccin; }];
        # Dark base mode, so the Macchiato flavor applies.
        appearance.theme = "obsidian";
      };
      # Keep data.json writable and outside the Nix store: configure Fastmail
      # WebDAV and its app password in Remotely Save's settings on each host.
    };
  };

  home.activation.seedClaudianSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/ObsidianVault/.claudian/claudian-settings.json"
    if [ ! -e "$settings" ]; then
      run mkdir -p "$(dirname "$settings")"
      run install -m 644 ${claudianSettings} "$settings"
    fi
  '';
}
