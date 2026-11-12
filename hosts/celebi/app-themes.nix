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
# - Discord: see ./discord.nix (Vencord theme, enabled automatically).
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
  # More contrast than upstream: Element's panes share one canvas token, so
  # darken it to crust with raised surfaces (menus, dialogs) on mantle and
  # hover/selection on base, lift the panel dividers from surface0 to
  # surface2, and brighten secondary text to subtext1.
  elementTheme = lib.recursiveUpdate (lib.importJSON ./themes/element-catppuccin-macchiato-mauve.json) {
    compound = {
      "--cpd-color-theme-bg" = "#181926";
      "--cpd-color-bg-canvas-default" = "#181926";
      "--cpd-color-bg-canvas-default-level-1" = "#1e2030";
      "--cpd-color-bg-subtle-secondary" = "#24273a";
      "--cpd-color-bg-subtle-primary" = "#5b6078";
      "--cpd-color-text-secondary" = "#b8c0e0";
    };
  };
in
{
  programs.firefox = {
    enable = true;
    # Keep the existing profile where it is (silences the 26.05 default-path
    # change warning; the new XDG default would mean moving ~/.mozilla).
    configPath = ".mozilla/firefox";
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

  xdg.dataFile."themes/telegram/catppuccin-macchiato-mauve.tdesktop-palette".source =
    ./themes/telegram-catppuccin-macchiato-mauve.tdesktop-palette;
}
