# celebi's Plasma layout: a thin top bar for status, an auto-hiding floating
# dock for open apps, vicinae on Meta for launching, and Catppuccin Macchiato
# (mauve) with frosted translucency throughout.
{ lib, pkgs, ... }:

let
  uiFont = "Atkinson Hyperlegible Next";

  # Plasma style: a full copy of Breeze (which follows the colour scheme)
  # with popup and tooltip backgrounds at 50% instead of 85% opacity, so
  # notifications, tray popups, the calendar and the top-bar menus show the
  # blur behind them.
  glassStyle = pkgs.runCommand "plasma-style-celebi-glass" { nativeBuildInputs = [ pkgs.jq ]; } ''
    cp -r --no-preserve=mode ${pkgs.kdePackages.libplasma}/share/plasma/desktoptheme/default $out
    for svg in translucent/dialogs/background translucent/widgets/tooltip; do
      gunzip -c "$out/$svg.svgz" | sed 's/opacity:0\.85;/opacity:0.5;/g' | gzip -n > "$out/$svg.svgz.new"
      mv "$out/$svg.svgz.new" "$out/$svg.svgz"
      gunzip -c "$out/$svg.svgz" | grep -q 'opacity:0\.5;'
    done
    jq '.KPlugin.Id = "celebi-glass" | .KPlugin.Name = "Breeze Glass (celebi)"' \
      "$out/metadata.json" > metadata.json
    mv metadata.json "$out/metadata.json"
  '';

  # Which blur replacement KWin runs (both are installed in
  # configuration.nix): "glass" for the liquid-glass look, or
  # "better_blur_dx" for plain frosted glass.
  blurEffect = "glass";

  # The Glass settings that cost the most GPU time, plugged in vs on battery:
  # popups and notifications blur a notch stronger than the bars, plus edge
  # lighting and refraction; on battery a lighter blur and neither extra.
  # glass-power applies one set when PowerDevil switches profile.
  glassPowered = {
    ac = {
      BlurStrength = 10;
      DockBlurStrength = 8;
      EdgeLighting = true;
      RefractionStrength = 8;
    };
    battery = {
      BlurStrength = 6;
      DockBlurStrength = 6;
      EdgeLighting = false;
      RefractionStrength = 0;
    };
  };

  glassPower = pkgs.writeShellApplication {
    name = "glass-power";
    runtimeInputs = [
      pkgs.kdePackages.kconfig
      pkgs.kdePackages.qttools
    ];
    text =
      let
        apply = settings: lib.concatStrings (lib.mapAttrsToList (key: value: ''
          kwriteconfig6 --file kwinrc --group Effect-blurplus --key ${key} ${if builtins.isBool value then lib.boolToString value else toString value}
        '') settings);
      in
      ''
        case "''${1:-}" in
          ac)
        ${apply glassPowered.ac}    ;;
          battery)
        ${apply glassPowered.battery}    ;;
          *) echo "usage: glass-power ac|battery" >&2; exit 2 ;;
        esac
        qdbus org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect glass >/dev/null || true
      '';
  };

  # Desktops 2 and 3 are where the remote sessions live; see the Remmina
  # window rules below.
  desktops = [
    "local"
    "devbox"
    "rowlett"
    "scratch"
  ];

  # Fixed-width spacer for the dock's ends (see the dock below).
  dockEdge = {
    panelSpacer = {
      expanding = false;
      length = 14;
    };
  };

  # A hidden Panel Colorizer instance per panel: it swaps the stock panel
  # background for a translucent Macchiato tint with blur behind and a faint
  # white hairline edge. Only the keys changed here; the widget merges them
  # over its own defaults.
  glass =
    { alpha
    , radius ? 0
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
    ./obsidian-launcher.nix
    ./remmina.nix
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
              shadow = true;
            })
            # End margins as real spacers (not colorizer padding) so the
            # fit-to-content width grows with the running apps; at least the
            # radius, so the end tiles clear the rounded corners.
            dockEdge
            {
              iconTasks.launchers = [
                "preferred://browser"
                "preferred://filemanager"
                "file:///etc/profiles/per-user/chris/share/applications/kitty.desktop"
                "file:///etc/profiles/per-user/chris/share/applications/obsidian.desktop"
                "file:///etc/profiles/per-user/chris/share/applications/org.remmina.Remmina.desktop"
                "file:///etc/profiles/per-user/chris/share/applications/spotify.desktop"
                "file:///etc/profiles/per-user/chris/share/applications/discord.desktop"
                "file:///etc/profiles/per-user/chris/share/applications/element-desktop.desktop"
                "file:///etc/profiles/per-user/chris/share/applications/org.telegram.desktop.desktop"
              ];
            }
            dockEdge
          ];
        }
      ];
    })
  ];

  xdg.dataFile."plasma/desktoptheme/celebi-glass".source = glassStyle;

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
        "applications:obsidian"
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
    workspace.theme = "celebi-glass";

    # Glass Qt style and window decoration (the Glass effect's companions):
    # translucent title bars, and see-through menus, toolbars, tab bars and
    # Dolphin's sidebar, all blurred by KWin.
    workspace.widgetStyle = "Glass";
    workspace.windowDecorations = {
      library = "org.kde.glass";
      theme = "Glass";
    };
    configFile.glassrc.Style = {
      MenuOpacity = 75;
      MenuBarOpacity = 70;
      ToolBarOpacity = 70;
      TabBarOpacity = 80;
      DolphinSidebarOpacity = 60;
    };

    # Lighter glass on battery (see glassPowered); PowerDevil runs this when
    # it loads each power profile.
    configFile.powerdevilrc = {
      "AC/RunScript".ProfileLoadCommand = "${lib.getExe glassPower} ac";
      "Battery/RunScript".ProfileLoadCommand = "${lib.getExe glassPower} battery";
      "LowBattery/RunScript".ProfileLoadCommand = "${lib.getExe glassPower} battery";
    };

    # Installed system-wide in configuration.nix so SDDM shares it.
    workspace.cursor = {
      theme = "Bibata-Modern-Classic";
      size = 20;
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

      # macOS-style genie into the dock icon.
      effects.minimization.animation = "magiclamp";
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
        better_blur_dxEnabled = blurEffect == "better_blur_dx";
        glassEnabled = blurEffect == "glass";
        kwin4_effect_shapecornersEnabled = true;
      };

      # Frosted glass behind translucent panels, popups and vicinae: strong
      # blur, a little noise against banding, extra saturation so the
      # wallpaper's color shows through, and a mild refraction bulge at the
      # edges for the liquid-glass highlight.
      Effect-better-blur-dx = {
        BlurStrength = 8;
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

      # Glass: the same frosted base plus edge lighting (a brighter rim) and
      # a stronger refraction bulge with a hint of RGB fringing, for the
      # liquid-glass look on windows and popups. Panels are left to Panel
      # Colorizer's own shape (no Glass corner radius, rim or refraction):
      # those also hit the full-width top bar, rounding its ends and lining
      # its screen edges.
      Effect-blurplus = glassPowered.ac // {
        NoiseStrength = 3;
        Brightness = 0.95;
        Saturation = 1.6;
        Contrast = 1.0;
        RefractionEdgeSize = 14;
        RefractionNormalPow = 2;
        RefractionRGBFringing = 2;
        TopCornerRadius = 10;
        BottomCornerRadius = 10;
        MenuCornerRadius = 8;
        DockCornerRadius = 0;
        # Despite the name, true *excludes* panels from edge lighting.
        EdgeLightingDock = true;
        RefractionExcludeDocks = true;
        # The Glass app style draws window backgrounds fully transparent and
        # relies on this tint for the frosted body: Catppuccin base at ~78%.
        # Panels, menus, popups/notifications and tooltips already paint
        # their own backgrounds, so they're left untinted.
        TintColor = "#C824273A";
        ExcludeDocks = true;
        ExcludeMenus = true;
        ExcludeOSD = true;
        ExcludeTooltips = true;
        WindowClasses = "";
      };

      # Rounded windows with a thin dark outline and no inner highlight.
      # vicinae and Plasma's own popups (plasmashell: notifications, tray,
      # menus) already draw rounded frames, which this effect clips again.
      Round-Corners = {
        Size = 10;
        InactiveCornerRadius = 10;
        OutlineColor = "24,25,38";
        InactiveOutlineColor = "24,25,38";
        SecondOutlineThickness = 0;
        InactiveSecondOutlineThickness = 0;
        ActiveSecondOutlineAlpha = 0;
        InactiveSecondOutlineAlpha = 0;
        Exclusions = "vicinae,plasmashell";
      };
    };

    # Keep notifications coming during fullscreen apps (Plasma holds them
    # by default), so local pings still show over a fullscreen Remmina
    # session.
    configFile.plasmanotifyrc.DoNotDisturb.WhenFullscreen = false;

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
