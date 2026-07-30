# common/devbox/xfce-panel.nix
#
# Declarative XFCE bottom panel for the devbox VM (home-manager). A single
# bottom panel:
#
#   [Whisker menu] | kitty  firefox  thunar  chromium  sysmon  screenshot
#       … window buttons (tasklist) … | systray (incl. clipman)  clock
#
# XFCE stores panel config in xfconf-backed XML. We ship it read-only from the
# Nix store: xfce4-panel loads it fine at session start and renders the layout;
# right-click tweaks just won't persist (edit this file instead — the whole
# point of keeping it in config). After a rebuild, log out/in of the RDP
# session or run `xfce4-panel -r` to reload.
#
# Each launcher plugin (ids 3-8) pairs with a launcher-<id>/ dir holding a
# self-contained .desktop file referenced by the plugin's `items` array.
{ ... }:

let
  launcher = name: exec: icon: ''
    [Desktop Entry]
    Version=1.0
    Type=Application
    Name=${name}
    Exec=${exec}
    Icon=${icon}
    Terminal=false
    StartupNotify=true
  '';
in
{
  xdg.configFile = {
    "xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <channel name="xfce4-panel" version="1.0">
        <property name="configver" type="int" value="2"/>
        <property name="panels" type="array">
          <value type="int" value="1"/>
          <property name="panel-1" type="empty">
            <property name="position" type="string" value="p=8;x=0;y=0"/>
            <property name="length" type="uint" value="100"/>
            <property name="position-locked" type="bool" value="true"/>
            <property name="icon-size" type="uint" value="22"/>
            <property name="size" type="uint" value="36"/>
            <property name="plugin-ids" type="array">
              <value type="int" value="1"/>
              <value type="int" value="2"/>
              <value type="int" value="3"/>
              <value type="int" value="4"/>
              <value type="int" value="5"/>
              <value type="int" value="6"/>
              <value type="int" value="7"/>
              <value type="int" value="8"/>
              <value type="int" value="9"/>
              <value type="int" value="10"/>
              <value type="int" value="12"/>
            </property>
          </property>
        </property>
        <property name="plugins" type="empty">
          <property name="plugin-1" type="string" value="whiskermenu"/>
          <property name="plugin-2" type="string" value="separator">
            <property name="style" type="uint" value="1"/>
          </property>
          <property name="plugin-3" type="string" value="launcher">
            <property name="items" type="array">
              <value type="string" value="kitty.desktop"/>
            </property>
          </property>
          <property name="plugin-4" type="string" value="launcher">
            <property name="items" type="array">
              <value type="string" value="firefox.desktop"/>
            </property>
          </property>
          <property name="plugin-5" type="string" value="launcher">
            <property name="items" type="array">
              <value type="string" value="thunar.desktop"/>
            </property>
          </property>
          <property name="plugin-6" type="string" value="launcher">
            <property name="items" type="array">
              <value type="string" value="chromium.desktop"/>
            </property>
          </property>
          <property name="plugin-7" type="string" value="launcher">
            <property name="items" type="array">
              <value type="string" value="taskmanager.desktop"/>
            </property>
          </property>
          <property name="plugin-8" type="string" value="launcher">
            <property name="items" type="array">
              <value type="string" value="screenshooter.desktop"/>
            </property>
          </property>
          <property name="plugin-9" type="string" value="tasklist">
            <property name="grouping" type="uint" value="1"/>
            <property name="show-labels" type="bool" value="true"/>
          </property>
          <property name="plugin-10" type="string" value="systray">
            <property name="square-icons" type="bool" value="true"/>
          </property>
          <property name="plugin-12" type="string" value="clock">
            <property name="digital-layout" type="uint" value="3"/>
            <property name="digital-time-format" type="string" value="%a %b %-d  %H:%M"/>
          </property>
        </property>
      </channel>
    '';

    # Launcher desktop files (dir name = launcher-<plugin-id>).
    "xfce4/panel/launcher-3/kitty.desktop".text = launcher "Kitty" "kitty" "kitty";
    "xfce4/panel/launcher-4/firefox.desktop".text = launcher "Firefox" "firefox" "firefox";
    "xfce4/panel/launcher-5/thunar.desktop".text = launcher "Files" "thunar" "org.xfce.thunar";
    "xfce4/panel/launcher-6/chromium.desktop".text = launcher "Chromium" "chromium" "chromium";
    "xfce4/panel/launcher-7/taskmanager.desktop".text =
      launcher "System Monitor" "xfce4-taskmanager" "org.xfce.taskmanager";
    "xfce4/panel/launcher-8/screenshooter.desktop".text =
      launcher "Screenshot" "xfce4-screenshooter" "org.xfce.screenshooter";

    # Clipman as a standalone tray daemon — the panel *plugin* "clipman"
    # doesn't load on current XFCE, so run the daemon and let it live in the
    # systray instead. Clipboard history works the same.
    "autostart/xfce4-clipman.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Clipman
      Exec=xfce4-clipman
      Terminal=false
      StartupNotify=false
      X-XFCE-Autostart-enabled=true
    '';
  };
}
