{
  launchers,
  wallpaper ? null,
  extraSystrayItems ? [ ],
  extraShortcuts ? { },
  keyboardOptions ? [ ],
}:

{ lib, ... }:

{
  programs.plasma = {
    enable = true;

    input.keyboard.options = keyboardOptions;

    workspace = lib.optionalAttrs (wallpaper != null) { inherit wallpaper; };

    panels = [
      {
        location = "bottom";
        widgets = [
          "org.kde.plasma.kickoff"
          "org.kde.plasma.pager"
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
  };
}
