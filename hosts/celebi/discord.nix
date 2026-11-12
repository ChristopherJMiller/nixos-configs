# Discord with Vencord and OpenASAR, the Catppuccin theme and a few Vencord
# plugins switched on. Same ~/.config/discord as stock Discord, so the login
# carries over. Client mods are against Discord's terms; enforcement for
# this kind of mod is rare, but it's at the account's own risk.
pkgs-unstable:

{
  lib,
  pkgs,
  vencord-latest,
  ...
}:

let
  theme = "catppuccin-macchiato-mauve.theme.css";

  plugins = lib.genAttrs [
    "NoTrack" # block Discord's telemetry (always on in Vencord anyway)
    "ClearURLs" # strip tracking parameters from links
    "ImageZoom" # magnifier on image previews
    "PlatformIndicators" # desktop / mobile / web next to names
    "CallTimer"
    "SilentTyping" # don't broadcast "is typing…"
    "VolumeBooster" # per-user volume past 200%
  ] (_: { enabled = true; });
in
{
  home.packages = [
    (pkgs-unstable.discord.override {
      withVencord = true;
      # The pinned unstable's Vencord fell behind Discord's web app and
      # left a blank window; see nixpkgs-latest in flake.nix.
      vencord = vencord-latest;
      # Faster startup, no update-check splash.
      withOpenASAR = true;
    })
  ];

  # No managed ~/.config/discord/settings.json: Discord and OpenASAR rewrite
  # it, and nixpkgs' wrapper already sets SKIP_HOST_UPDATE there on launch.

  xdg.configFile."Vencord/themes/${theme}".text = ''
    /**
     * @name Catppuccin Macchiato (Mauve)
     * @author catppuccin
     * @description Soothing pastel theme for Discord
     * @source https://github.com/catppuccin/discord
     */
    @import url("https://catppuccin.github.io/discord/dist/catppuccin-macchiato-mauve.theme.css");
  '';

  # Vencord rewrites its own settings.json, so rather than owning the file,
  # merge the theme and plugin switches into it on every activation and
  # leave everything else as Vencord (or a hand edit) left it. A running
  # Discord picks this up on its next start.
  home.activation.vencordSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.config/Vencord/settings/settings.json"
    current='{}'
    if [ -s "$settings" ]; then
      current=$(cat "$settings")
    fi
    merged=$(printf '%s' "$current" | ${lib.getExe pkgs.jq} \
      --argjson plugins ${lib.escapeShellArg (builtins.toJSON plugins)} \
      --arg theme ${lib.escapeShellArg theme} \
      '.plugins = ((.plugins // {}) * $plugins)
       | .enabledThemes = (((.enabledThemes // []) + [$theme]) | unique)')
    run mkdir -p "$(dirname "$settings")"
    if [[ ! -v DRY_RUN ]]; then
      printf '%s\n' "$merged" > "$settings"
    fi
  '';
}
