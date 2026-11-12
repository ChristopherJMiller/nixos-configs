# celebi's Plasma layout: a thin top bar for status, an auto-hiding floating
# dock for open apps, fuzzel on Meta for launching, and Catppuccin Macchiato
# (mauve) with frosted translucency throughout.
{ pkgs, ... }:

let
  # Desktops 2 and 3 are where the remote sessions live; see the Remmina
  # window rules below.
  desktops = [
    "local"
    "devbox"
    "rowlett"
    "scratch"
  ];
in
{
  imports = [
    ./system-menu.nix
    (import ../../common/plasma.nix {
      extraFavorites = [
        "chatgpt"
        "com.anthropic.Claude"
      ];
      wallpaper = "${./wallpaper.png}";
      launchers = [ ];
      virtualDesktops = builtins.length desktops;
      panels = [
        # Top bar: system menu + desktops on the left, clock centered, tray right.
        {
          location = "top";
          height = 30;
          floating = false;
          opacity = "translucent";
          widgets = [
            "xyz.chrismiller.systemmenu"
            {
              pager.general = {
                displayedText = "desktopNumber";
                showWindowOutlines = false;
                navigationWrapsAround = true;
              };
            }
            "org.kde.plasma.panelspacer"
            {
              digitalClock = {
                date.enable = true;
                date.format = {
                  custom = "ddd d MMM";
                };
                date.position = "besideTime";
                time.showSeconds = "never";
              };
            }
            "org.kde.plasma.panelspacer"
            {
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
  ];

  # App launcher on Meta. Empty query lists apps by how often they're
  # launched, so Meta, ↓, Enter reaches the usual suspects.
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        terminal = "kitty";
        layer = "overlay";
        width = 36;
        lines = 10;
        horizontal-pad = 24;
        vertical-pad = 16;
        inner-pad = 8;
        prompt = "'❯ '";
      };
      # Catppuccin Macchiato, mauve accent.
      colors = {
        background = "24273add";
        text = "cad3f5ff";
        prompt = "b8c0e0ff";
        placeholder = "8087a2ff";
        input = "cad3f5ff";
        match = "c6a0f6ff";
        selection = "5b6078ff";
        selection-text = "cad3f5ff";
        selection-match = "c6a0f6ff";
        counter = "8087a2ff";
        border = "c6a0f6ff";
      };
      border = {
        width = 2;
        radius = 14;
      };
    };
  };

  programs.plasma = {
    # Color scheme only (not the full look-and-feel package, which would reset
    # the panel layout above). The Breeze Plasma style and window decorations
    # pick up the colors from it.
    workspace.colorScheme = "CatppuccinMacchiatoMauve";

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

      # Frosted glass behind translucent panels, popups and KRunner. A little
      # noise keeps it from looking like a flat smear.
      effects.blur = {
        enable = true;
        strength = 13;
        noiseStrength = 3;
      };
    };

    # KRunner stays on Alt+Space for searching everything else (files,
    # calculator, ...), dropping down from the top.
    krunner = {
      position = "top";
      historyBehavior = "enableSuggestions";
    };

    hotkeys.commands.launcher = {
      name = "App launcher";
      key = "Meta+Space";
      command = "fuzzel";
    };

    # Tapping Meta alone fires the launcher hotkey above.
    configFile.kwinrc.ModifierOnlyShortcuts.Meta = "org.kde.kglobalaccel,/component/plasma_manager_commands_desktop,org.kde.kglobalaccel.Component,invokeShortcut,launcher";

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
