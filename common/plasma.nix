{
  launchers,
  wallpaper ? null,
  extraSystrayItems ? [ ],
  extraShortcuts ? { },
  keyboardOptions ? [ ],
  virtualDesktops ? 4,
  # Desktop ids (no .desktop) for the right-hand launcher widget, just left of
  # the system tray (packages/plasma-widelaunchers). It collapses to one icon
  # when the panel is crowded and hides unless a >= 1600 px screen is
  # connected. Empty = no widget, and the panel is exactly as before.
  rightLaunchers ? [ ],
}:

{ lib, pkgs, ... }:

{
  home.packages = lib.optional (rightLaunchers != [ ]) (
    pkgs.callPackage ../packages/plasma-widelaunchers { }
  );

  programs.plasma = {
    enable = true;

    input.keyboard.options = keyboardOptions;

    kwin.virtualDesktops.number = virtualDesktops;

    workspace = lib.optionalAttrs (wallpaper != null) { inherit wallpaper; };

    panels = [
      {
        location = "bottom";
        widgets = [
          "org.kde.plasma.kickoff"
          {
            name = "org.kde.plasma.icontasks";
            extraConfig = ''
              (w) => {
                w.currentConfigGroup = ["Configuration", "General"];
                w.writeConfig("launchers", ${builtins.toJSON launchers});
                w.reloadConfig();
              }
            '';
          }
        ]
        ++ lib.optionals (rightLaunchers != [ ]) [
          {
            name = "xyz.chrismiller.widelaunchers";
            config.General = {
              launchers = rightLaunchers;
              minScreenWidth = 1600;
            };
          }
        ]
        ++ [
          "org.kde.plasma.marginsseparator"
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
            ] ++ extraSystrayItems;
          }
          "org.kde.plasma.digitalclock"
          "org.kde.plasma.showdesktop"
        ];
      }
    ];

    shortcuts = extraShortcuts;
  };
}
