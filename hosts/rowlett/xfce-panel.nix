# hosts/rowlett/xfce-panel.nix
#
# Declarative XFCE bottom panel for rowlett's *RDP* session (home-manager).
# XFCE only runs under xrdp here (see services.xrdp in ./configuration.nix);
# the local seat0 session is Plasma and untouched by this. Modelled on
# common/devbox/xfce-panel.nix. Single bottom panel:
#
#   [Whisker menu] | firefox  thunar  kitty | … window buttons … | systray  clock
#
# XFCE stores panel config in xfconf-backed XML; we ship it from the Nix
# store with `force = true` so home-manager overwrites whatever XFCE's
# first-run "panel setup" dialog wrote. Right-click tweaks in the panel won't
# persist across rebuilds — edit this file instead. To apply after a rebuild
# without logging out of the RDP session: `systemctl --user restart xfconfd`
# (xfconfd caches channels in memory and does not watch the files), then
# `xfce4-panel -r` inside the session.
#
# Each launcher plugin (ids 3-5) pairs with a launcher-<id>/ dir holding a
# self-contained .desktop file referenced by the plugin's `items` array.
{ ... }:

let
  launcher = name: exec: icon: {
    force = true;
    text = ''
      [Desktop Entry]
      Version=1.0
      Type=Application
      Name=${name}
      Exec=${exec}
      Icon=${icon}
      Terminal=false
      StartupNotify=true
    '';
  };
in
{
  xdg.configFile = {
    "xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" = {
      force = true;
      text = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <channel name="xfce4-panel" version="1.0">
          <property name="configver" type="int" value="2"/>
          <property name="panels" type="array">
            <value type="int" value="1"/>
            <property name="dark-mode" type="bool" value="true"/>
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
                <value type="string" value="firefox.desktop"/>
              </property>
            </property>
            <property name="plugin-4" type="string" value="launcher">
              <property name="items" type="array">
                <value type="string" value="thunar.desktop"/>
              </property>
            </property>
            <property name="plugin-5" type="string" value="launcher">
              <property name="items" type="array">
                <value type="string" value="kitty.desktop"/>
              </property>
            </property>
            <property name="plugin-6" type="string" value="separator">
              <property name="style" type="uint" value="1"/>
            </property>
            <property name="plugin-7" type="string" value="tasklist">
              <property name="grouping" type="uint" value="1"/>
              <property name="show-labels" type="bool" value="true"/>
            </property>
            <property name="plugin-8" type="string" value="systray">
              <property name="square-icons" type="bool" value="true"/>
            </property>
            <property name="plugin-9" type="string" value="clock">
              <property name="digital-layout" type="uint" value="3"/>
              <property name="digital-time-format" type="string" value="%a %b %-d  %H:%M"/>
            </property>
          </property>
        </channel>
      '';
    };

    # Launcher desktop files (dir name = launcher-<plugin-id>).
    "xfce4/panel/launcher-3/firefox.desktop" = launcher "Firefox" "firefox" "firefox";
    "xfce4/panel/launcher-4/thunar.desktop" = launcher "Files" "thunar" "org.xfce.thunar";
    "xfce4/panel/launcher-5/kitty.desktop" = launcher "Kitty" "kitty" "kitty";
  };
}
