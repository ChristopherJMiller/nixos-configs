# Catppuccin Macchiato Mauve for the apps that don't follow the Plasma colour
# scheme. Each route leaves the app's profile and sign-in untouched:
#
# - Firefox: theme add-on force-installed by policy. No `profiles` are set,
#   so home-manager never writes profiles.ini. Switch to it once in
#   about:addons → Themes.
# - Spotify: Spicetify-patched client with the Catppuccin theme; login lives
#   in ~/.config/spotify, which it doesn't touch. Pick Mauve once in the
#   theme's settings inside Spotify.
# - Element: theme defined in config.json; the session is in IndexedDB.
#   Select it once in Settings → Appearance if another theme is chosen.
# - Discord: Vencord (see home.nix) with the Catppuccin theme in its themes
#   folder; enable it once in Settings → Vencord → Themes. Vencord writes its
#   own settings.json, so that stays unmanaged.
# - Telegram: palette dropped in ~/.local/share/themes/telegram; apply it
#   once via Settings → Chat Settings → Choose from file (Telegram keeps
#   themes inside its own data, so this can't be declarative).
pkgs-unstable:

{
  lib,
  pkgs,
  spicePkgs,
  ...
}:

let
  # Mozilla-signed release from github.com/catppuccin/firefox.
  firefoxTheme = pkgs.fetchurl {
    url = "https://github.com/catppuccin/firefox/releases/download/old/catppuccin_macchiato_mauve.xpi";
    hash = "sha256-9a9i7Wvwwn1BL2gyVTXjn95O0IxFtf2dkob6++27nkc=";
  };

  # From element.catppuccin.com/macchiato/mauve.json.
  elementTheme = lib.importJSON ./themes/element-catppuccin-macchiato-mauve.json;
in
{
  programs.firefox = {
    enable = true;
    policies.ExtensionSettings."{998d0435-a079-4dcc-ad24-7333b3463bca}" = {
      installation_mode = "force_installed";
      install_url = "file://${firefoxTheme}";
    };
  };

  programs.spicetify = {
    enable = true;
    theme = spicePkgs.themes.catppuccin;
    colorScheme = "macchiato";
  };

  programs.element-desktop = {
    enable = true;
    # Unstable: stable's electron isn't in the binary cache.
    package = pkgs-unstable.element-desktop;
    settings = {
      setting_defaults.custom_themes = [ elementTheme ];
      default_theme = "custom-${elementTheme.name}";
    };
  };

  xdg.configFile."Vencord/themes/catppuccin-macchiato-mauve.theme.css".text = ''
    /**
     * @name Catppuccin Macchiato (Mauve)
     * @author catppuccin
     * @description Soothing pastel theme for Discord
     * @source https://github.com/catppuccin/discord
     */
    @import url("https://catppuccin.github.io/discord/dist/catppuccin-macchiato-mauve.theme.css");
  '';

  xdg.dataFile."themes/telegram/catppuccin-macchiato-mauve.tdesktop-palette".source =
    ./themes/telegram-catppuccin-macchiato-mauve.tdesktop-palette;
}
