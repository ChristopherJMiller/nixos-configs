# Catppuccin Macchiato/Mauve, matching the shared terminal and celebi.
{ config, pkgs, ... }:
let
  themeName = "catppuccin-macchiato-mauve-standard";

  # catppuccin-gtk 1.0.3 ships xfwm4/themerc but none of the title-bar PNGs:
  # build.py copies them from patches/xfwm4/generated/, a dir only its
  # separate inkscape script (generate_assets.py) creates, and from the wrong
  # path at that (missing sources/). xfwm4 accepts a themerc-only theme and
  # draws windows with NO title bar, buttons or border. Render them here the
  # way that script does: Colloid's dark xfwm4 SVG with the title-bar greys
  # swapped for Macchiato base (focused) and mantle (unfocused).
  themePackage =
    (pkgs.catppuccin-gtk.override {
      variant = "macchiato";
      accents = [ "mauve" ];
    }).overrideAttrs
      (old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.inkscape ];
        postInstall = (old.postInstall or "") + ''
          export HOME=$TMPDIR
          svg=$TMPDIR/xfwm4-assets.svg
          ids=sources/colloid/src/assets/xfwm4/assets.txt
          sed -e 's/#242424/#24273a/g' -e 's/#2c2c2c/#1e2030/g' \
            sources/patches/xfwm4/assets-dark.svg > $svg
          for screen in :96 -hdpi:144 -xhdpi:192; do
            dir=$out/share/themes/${themeName}''${screen%%:*}/xfwm4
            actions=
            for id in $(cat $ids); do
              actions+="export-id:$id;export-id-only;export-dpi:''${screen##*:};"
              actions+="export-filename:$dir/$id.png;export-do;"
            done
            inkscape --actions="$actions" $svg
            # inkscape exits 0 even when an export fails.
            [ "$(ls $dir/*.png | wc -l)" -eq "$(wc -w < $ids)" ]
          done
        '';
      });
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
      package = themePackage;
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
      # Window menu left; minimise, maximise, close right (xfwm4's default).
      "general/button_layout" = "O|HMC";
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
    xfce4-session = {
      "shutdown/LockScreen" = false;
      # Don't start xfce4-session's own ssh-agent: it would claim
      # SSH_AUTH_SOCK for the session and the systemd user manager, hiding
      # gpg-agent, which is the SSH agent here (guest.nix, GnuPG section).
      "startup/ssh-agent/enabled" = false;
    };
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
