# A Mac-style system menu for the top-left of the top bar: a snowflake that
# drops down About / Settings / btop and the session actions. Installed as a
# directory (Plasma refuses plasmoid files symlinked in one by one, which is
# what a plain home.file does); plasma.nix places it by its id.
{ pkgs, ... }:

let
  id = "xyz.chrismiller.systemmenu";
  qdbus = "${pkgs.kdePackages.qttools}/bin/qdbus";

  metadata = builtins.toJSON {
    KPlugin = {
      Id = id;
      Name = "System Menu";
      Description = "About, settings and session actions";
      Icon = "nix-snowflake-white";
      Authors = [{ Name = "Christopher Miller"; }];
      License = "MIT";
      Version = "1.0";
    };
    KPackageStructure = "Plasma/Applet";
    X-Plasma-API-Minimum-Version = "6.0";
  };

  # null entries render as separators.
  entries = [
    {
      text = "About This Computer";
      icon = "help-about";
      cmd = "kinfocenter";
    }
    {
      text = "System Settings…";
      icon = "systemsettings";
      cmd = "systemsettings";
    }
    {
      text = "Activity Monitor";
      icon = "utilities-system-monitor";
      cmd = "kitty --title btop -e btop";
    }
    null
    {
      text = "Sleep";
      icon = "system-suspend";
      cmd = "systemctl suspend";
    }
    {
      text = "Lock Screen";
      icon = "system-lock-screen";
      cmd = "loginctl lock-session";
    }
    {
      text = "Log Out…";
      icon = "system-log-out";
      cmd = "${qdbus} org.kde.LogoutPrompt /LogoutPrompt promptLogout";
    }
    null
    {
      text = "Restart…";
      icon = "system-reboot";
      cmd = "${qdbus} org.kde.LogoutPrompt /LogoutPrompt promptReboot";
    }
    {
      text = "Shut Down…";
      icon = "system-shutdown";
      cmd = "${qdbus} org.kde.LogoutPrompt /LogoutPrompt promptShutDown";
    }
  ];

  mainQml = ''
    import QtQuick
    import QtQuick.Layouts
    import org.kde.plasma.plasmoid
    import org.kde.plasma.components as PlasmaComponents
    import org.kde.plasma.plasma5support as P5Support
    import org.kde.kirigami as Kirigami

    PlasmoidItem {
        id: root
        preferredRepresentation: compactRepresentation
        Plasmoid.icon: "nix-snowflake-white"
        toolTipMainText: "System"

        P5Support.DataSource {
            id: executable
            engine: "executable"
            connectedSources: []
            onNewData: (sourceName, data) => disconnectSource(sourceName)
        }

        function run(cmd) {
            root.expanded = false
            executable.connectSource(cmd)
        }

        compactRepresentation: MouseArea {
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
            Kirigami.Icon {
                anchors.fill: parent
                source: Plasmoid.icon
                active: parent.containsMouse || root.expanded
            }
        }

        fullRepresentation: ColumnLayout {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 13
            spacing: 0

            Repeater {
                model: ${builtins.toJSON entries}
                delegate: Loader {
                    required property var modelData
                    Layout.fillWidth: true
                    sourceComponent: modelData === null ? separatorComponent : entryComponent
                    Component {
                        id: separatorComponent
                        Item {
                            implicitHeight: Kirigami.Units.smallSpacing * 2 + 1
                            Kirigami.Separator {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                    Component {
                        id: entryComponent
                        PlasmaComponents.ItemDelegate {
                            text: modelData.text
                            icon.name: modelData.icon
                            onClicked: root.run(modelData.cmd)
                        }
                    }
                }
            }
        }
    }
  '';
in
{
  xdg.dataFile."plasma/plasmoids/${id}".source =
    pkgs.runCommand "plasma-system-menu"
      {
        inherit metadata mainQml;
        passAsFile = [
          "metadata"
          "mainQml"
        ];
      }
      ''
        mkdir -p $out/contents/ui
        cp $metadataPath $out/metadata.json
        cp $mainQmlPath $out/contents/ui/main.qml
      '';
}
