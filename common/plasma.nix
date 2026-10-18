{
  launchers,
  wallpaper ? null,
  extraSystrayItems ? [ ],
  extraShortcuts ? { },
  keyboardOptions ? [ ],
  virtualDesktops ? 4,
  # Desktop ids (no .desktop) to add to Kickoff's favorites, after KDE's
  # defaults. Added once at login whenever this list changes, so one removed
  # by hand stays removed until then.
  extraFavorites ? [ ],
}:

{ lib, pkgs, ... }:

{
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

    # Favorites live in kactivitymanagerd, not in the Kickoff applet's config,
    # so they survive the panel being rebuilt and are linked over D-Bus.
    startup.startupScript.favorites = lib.mkIf (extraFavorites != [ ]) {
      text = lib.concatMapStrings (id: ''
        ${pkgs.kdePackages.qttools}/bin/qdbus org.kde.ActivityManager /ActivityManager/Resources/Linking \
          LinkResourceToActivity org.kde.plasma.favorites.applications applications:${id}.desktop :global
      '') extraFavorites;
    };
  };
}
