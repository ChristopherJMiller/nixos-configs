# celebi's Plasma layout: a thin top bar for status, an auto-hiding floating
# dock for open apps, vicinae on Meta for launching, and Catppuccin Macchiato
# (mauve) with frosted translucency throughout.
{ pkgs, ... }:

let
  uiFont = "Atkinson Hyperlegible Next";

  # Desktops 2 and 3 are where the remote sessions live; see the Remmina
  # window rules below.
  desktops = [
    "local"
    "devbox"
    "rowlett"
    "scratch"
  ];

  # A hidden Panel Colorizer instance per panel: it swaps the stock panel
  # background for a translucent Macchiato tint with blur behind and a faint
  # white hairline edge. Only the keys changed here; the widget merges them
  # over its own defaults.
  glass =
    { alpha
    , radius ? 0
      # Horizontal inset for the widgets. On a rounded panel it should be at
      # least the radius, or the first and last task tiles poke their square
      # corners out past the curve.
    , padding ? 0
    , borderSides ? null
    , shadow ? false
    }:
    let
      corners = {
        topLeft = radius;
        topRight = radius;
        bottomRight = radius;
        bottomLeft = radius;
      };
    in
    {
      name = "luisbocanegra.panel.colorizer";
      config.General = {
        hideWidget = true;
        # Its D-Bus preset-switching helper needs python3; not used here.
        enableDBusService = false;
        globalSettings = builtins.toJSON {
          nativePanel.background = {
            enabled = true;
            opacity = 0;
            inherit shadow;
          };
          panel.normal = {
            enabled = true;
            blurBehind = true;
            backgroundColor = {
              enabled = true;
              sourceType = 0;
              custom = "#24273A";
              inherit alpha;
            };
            radius = {
              enabled = radius > 0;
              corner = corners;
            };
            padding = {
              enabled = padding > 0;
              side = {
                left = padding;
                right = padding;
                top = 0;
                bottom = 0;
              };
            };
            border = {
              enabled = true;
              width = 1;
              customSides = borderSides != null;
              custom.widths = if borderSides != null then borderSides else { };
              color = {
                enabled = true;
                sourceType = 0;
                custom = "#FFFFFF";
                alpha = 0.08;
              };
            };
          };
        };
      };
    };
in
{
  imports = [
    ./system-menu.nix
    ./tailnet-menu.nix
    (import ../../common/plasma.nix {
      extraFavorites = [
        "chatgpt"
        "com.anthropic.Claude"
      ];
      wallpaper = "${./wallpaper.png}";
      launchers = [ ];
      virtualDesktops = builtins.length desktops;
      panels = [
        # Top bar, Mac-style: system menu + desktops on the left, tray then
        # clock on the right.
        {
          location = "top";
          height = 30;
          floating = false;
          opacity = "translucent";
          widgets = [
            (glass {
              alpha = 0.45;
              borderSides = {
                left = 0;
                right = 0;
                top = 0;
                bottom = 1;
              };
            })
            "xyz.chrismiller.systemmenu"
            {
              panelSpacer = {
                expanding = false;
                length = 6;
              };
            }
            {
              pager.general = {
                displayedText = "desktopNumber";
                showWindowOutlines = false;
                navigationWrapsAround = true;
              };
            }
            "org.kde.plasma.panelspacer"
            "xyz.chrismiller.tailnet"
            {
              # Both are covered by the tailnet menu (Trayscale via "Exit nodes
              # & settings…", Remmina via quick connect); they stay reachable in
              # the tray overflow.
              systemTray.items.hidden = [
                "dev.deedles.Trayscale"
                "remmina-icon"
              ];
              systemTray.items.extra = [
                "org.kde.plasma.clipboard"
                "org.kde.plasma.notifications"
                "org.kde.plasma.cameraindicator"
                "org.kde.plasma.manage-inputmethod"
                "org.kde.plasma.devicenotifier"
                "org.kde.plasma.mediacontroller"
                "org.kde.plasma.volume"
                "org.kde.plasma.battery"
                "org.kde.plasma.printmanager"
                "org.kde.plasma.networkmanagement"
                "org.kde.plasma.brightness"
                "org.kde.kscreen"
                "org.kde.plasma.keyboardindicator"
                "org.kde.plasma.bluetooth"
                "org.kde.plasma.keyboardlayout"
              ];
            }
            {
              digitalClock = {
                # Without an explicit font the clock scales up to fill the
                # panel height.
                font = {
                  family = uiFont;
                  weight = 500;
                  size = 9;
                };
                date.enable = true;
                date.format = {
                  custom = "ddd d MMM";
                };
                date.position = "besideTime";
                time.showSeconds = "never";
              };
            }
          ];
        }
        # Dock: only what's pinned/open, slides up when the pointer hits the
        # bottom edge.
        {
          location = "bottom";
          height = 52;
          floating = true;
          lengthMode = "fit";
          alignment = "center";
          hiding = "autohide";
          opacity = "translucent";
          widgets = [
            (glass {
              alpha = 0.4;
              radius = 14;
              padding = 14;
              shadow = true;
            })
            {
              iconTasks.launchers = [
                "preferred://browser"
                "preferred://filemanager"
                "file:///etc/profiles/per-user/chris/share/applications/kitty.desktop"
                "file:///etc/profiles/per-user/chris/share/applications/org.remmina.Remmina.desktop"
                "file:///etc/profiles/per-user/chris/share/applications/spotify.desktop"
                "file:///etc/profiles/per-user/chris/share/applications/discord.desktop"
                "file:///etc/profiles/per-user/chris/share/applications/element-desktop.desktop"
                "file:///etc/profiles/per-user/chris/share/applications/org.telegram.desktop.desktop"
              ];
            }
          ];
        }
      ];
    })
  ];

  home.packages = [
    (pkgs.catppuccin-kde.override {
      flavour = [ "macchiato" ];
      accents = [ "mauve" ];
    })
    # Papirus-Dark with Catppuccin-tinted folders (workspace.iconTheme below).
    (pkgs.catppuccin-papirus-folders.override {
      flavor = "macchiato";
      accent = "mauve";
    })
  ];

  # App launcher on Meta. With no query it shows favorites first, then apps
  # ranked by how often and how recently they're opened, so Meta, ↓, Enter
  # reaches the usual suspects. Translucent with KWin blur behind it.
  programs.vicinae = {
    enable = true;
    systemd.enable = true;
    themes.catppuccin-macchiato-mauve = {
      meta = {
        version = 1;
        name = "Catppuccin Macchiato Mauve";
        description = "Catppuccin Macchiato with the mauve accent";
        variant = "dark";
        inherits = "catppuccin-macchiato";
      };
      colors.core = {
        accent = "#C6A0F6";
        accent_foreground = "#24273A";
      };
    };
    settings = {
      pop_to_root_on_close = true;
      favorites = [
        "applications:firefox"
        "applications:kitty"
        "applications:org.remmina.Remmina"
        "applications:com.anthropic.Claude"
        "applications:chatgpt"
      ];
      theme.dark.name = "catppuccin-macchiato-mauve";
      font.normal.family = uiFont;
      launcher_window = {
        opacity = 0.82;
        material = "auto";
        rounding = 16;
      };
    };
  };

  programs.plasma = {
    # Color scheme only (not the full look-and-feel package, which would reset
    # the panel layout above). The Breeze Plasma style and window decorations
    # pick up the colors from it.
    workspace.colorScheme = "CatppuccinMacchiatoMauve";
    workspace.iconTheme = "Papirus-Dark";

    # Installed system-wide in configuration.nix so SDDM shares it.
    workspace.cursor = {
      theme = "catppuccin-macchiato-mauve-cursors";
      size = 24;
    };

    # Lock screen on the desktop wallpaper; its colours and font already
    # follow the scheme and fonts below, so it matches the login screen.
    kscreenlocker.appearance.wallpaper = "${./wallpaper.png}";

    kwin = {
      virtualDesktops.names = desktops;

      # No window-menu icon on the left; keep the pin (all desktops) on the
      # right next to the usual buttons.
      titlebarButtons = {
        left = [ ];
        right = [
          "help"
          "on-all-desktops"
          "minimize"
          "maximize"
          "close"
        ];
      };

      # Stock blur off: Better Blur DX (below) replaces it.
      effects.blur.enable = false;
    };

    # Atkinson Hyperlegible Next for the UI, chosen for legibility; emoji
    # come from the fontconfig fallback set up in configuration.nix. Window
    # titles a touch heavier, Mac-style.
    fonts =
      let
        ui = pointSize: weight: {
          family = uiFont;
          inherit pointSize weight;
        };
      in
      {
        general = ui 10 400;
        menu = ui 10 400;
        toolbar = ui 10 400;
        windowTitle = ui 10 600;
        small = ui 8 400;
      };

    configFile.kwinrc = {
      Plugins = {
        better_blur_dxEnabled = true;
        kwin4_effect_shapecornersEnabled = true;
      };

      # Frosted glass behind translucent panels, popups and vicinae: strong
      # blur, a little noise against banding, extra saturation so the
      # wallpaper's color shows through, and a mild refraction bulge at the
      # edges for the liquid-glass highlight.
      Effect-better-blur-dx = {
        BlurStrength = 9;
        NoiseStrength = 3;
        Brightness = 95;
        Saturation = 175;
        Contrast = 100;
        CornerRadius = 10;
        WindowClasses = "";
        RefractionStrength = 6;
        RefractionMode = 0;
        RefractionEdgeSize = 14;
        RefractionCornerRadius = 10;
      };

      # Rounded windows with a thin dark outline and no inner highlight.
      # vicinae draws its own rounded frame, which this effect garbles.
      Round-Corners = {
        Size = 10;
        InactiveCornerRadius = 10;
        OutlineColor = "24,25,38";
        InactiveOutlineColor = "24,25,38";
        SecondOutlineThickness = 0;
        InactiveSecondOutlineThickness = 0;
        ActiveSecondOutlineAlpha = 0;
        InactiveSecondOutlineAlpha = 0;
        Exclusions = "vicinae";
      };
    };

    # KRunner stays on Alt+Space for searching everything else (files,
    # calculator, ...), dropping down from the top.
    krunner = {
      position = "top";
      historyBehavior = "enableSuggestions";
    };

    # In Plasma 6 a bare Meta tap is an ordinary global shortcut, so take it
    # from plasmashell (whose launcher applet is gone) and give it to
    # vicinae. Written to both places kglobalaccel keeps desktop-file
    # shortcuts, since it had already copied the old binding into the
    # services group.
    hotkeys.commands.launcher = {
      name = "App launcher";
      keys = [
        "Meta"
        "Meta+Space"
      ];
      command = "${pkgs.vicinae}/bin/vicinae toggle";
    };
    shortcuts."services/plasma-manager-commands.desktop".launcher = [
      "Meta"
      "Meta+Space"
    ];
    shortcuts.plasmashell."activate application launcher" = [ ];
    # Cleared so it can't double-fire alongside the shortcut above.
    configFile.kwinrc.ModifierOnlyShortcuts.Meta = "";

    # Ctrl+N jumps straight to desktop N (Ctrl+F-keys kept as well).
    shortcuts.kwin = builtins.listToAttrs (
      builtins.genList
        (
          i:
          let
            n = toString (i + 1);
          in
          {
            name = "Switch to Desktop ${n}";
            value = [
              "Ctrl+${n}"
              "Ctrl+F${n}"
            ];
          }
        )
        (builtins.length desktops)
    );

    # Remote sessions open on their own desktop.
    window-rules = [
      {
        description = "Remmina: devbox on its desktop";
        match = {
          window-class = {
            value = "org.remmina.Remmina";
            type = "exact";
          };
          title = {
            value = "devbox";
            type = "substring";
          };
        };
        apply.desktops = {
          value = "Desktop_2";
          apply = "initially";
        };
      }
      {
        description = "Remmina: rowlett on its desktop";
        match = {
          window-class = {
            value = "org.remmina.Remmina";
            type = "exact";
          };
          title = {
            value = "rowlett";
            type = "substring";
          };
        };
        apply.desktops = {
          value = "Desktop_3";
          apply = "initially";
        };
      }
    ];
  };
}
