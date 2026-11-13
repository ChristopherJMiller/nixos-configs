# Catppuccin Macchiato/Mauve, matching the shared terminal and celebi.
{ config, pkgs, ... }:
let
  themeName = "catppuccin-macchiato-mauve-standard";
in
{
  gtk = {
    enable = true;
    font = {
      name = "Atkinson Hyperlegible Next";
      package = pkgs.atkinson-hyperlegible-next;
      size = 11;
    };
    theme = {
      name = themeName;
      package = pkgs.catppuccin-gtk.override {
        variant = "macchiato";
        accents = [ "mauve" ];
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.catppuccin-papirus-folders.override {
        flavor = "macchiato";
        accent = "mauve";
      };
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4 = {
      theme = config.gtk.theme;
      extraConfig.gtk-application-prefer-dark-theme = true;
    };
  };

  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # xfsettingsd owns the GTK theme in XFCE; GTK settings.ini alone loses to it.
  xfconf.settings = {
    xsettings = {
      "Net/ThemeName" = themeName;
      "Net/IconThemeName" = "Papirus-Dark";
      "Gtk/FontName" = "Atkinson Hyperlegible Next 11";
      "Gtk/MonospaceFontName" = "JetBrainsMono Nerd Font 11";
      "Gtk/CursorThemeName" = "Bibata-Modern-Classic";
      "Gtk/CursorThemeSize" = 24;
    };
    xfwm4 = {
      "general/theme" = themeName;
      "general/title_font" = "Atkinson Hyperlegible Next Bold 11";
      # RDP renders directly; compositing adds work and can leave stale frames.
      "general/use_compositing" = false;
    };
    xfce4-screensaver = {
      "saver/enabled" = false;
      "saver/idle-activation/enabled" = false;
      "lock/enabled" = false;
      "lock/saver-activation/enabled" = false;
    };
    xfce4-power-manager = {
      "xfce4-power-manager/lock-screen-suspend-hibernate" = false;
      "xfce4-power-manager/dpms-enabled" = false;
      "xfce4-power-manager/blank-on-ac" = 0;
      "xfce4-power-manager/inactivity-on-ac" = 0;
    };
    xfce4-session."shutdown/LockScreen" = false;
  };

  # XFCE's preferred terminal is independent of $TERMINAL.
  xdg.configFile."xfce4/helpers.rc".text = ''
    TerminalEmulator=kitty
    WebBrowser=firefox
  '';
  xdg.dataFile."xfce4/helpers/kitty.desktop".text = ''
    [Desktop Entry]
    Type=X-XFCE-Helper
    Name=Kitty
    Icon=kitty
    X-XFCE-Category=TerminalEmulator
    X-XFCE-Binaries=kitty;
    X-XFCE-Commands=kitty;
    X-XFCE-CommandsWithParameter=kitty -e %s;
  '';
}
