# Tailnet menu for the top bar: a Tailscale mark that shows the connection
# state, and a popup with one-click remote desktops (each on its own virtual
# desktop, see the window rules in plasma.nix) plus the rest of the tailnet.
# Installed as a user plasmoid directory; plasma.nix places it by its id.
{ pkgs, ... }:

let
  id = "xyz.chrismiller.tailnet";

  # `desktop` matches the Remmina window rules in plasma.nix; 0 stays put.
  # `tailnet = false` for hosts reached through a subnet route, which have
  # no tailscale status of their own.
  remotes = [
    {
      name = "devbox";
      host = "devbox";
      profile = "devbox.remmina";
      port = 3389;
      desktop = 2;
      icon = "computer";
      tailnet = true;
    }
    {
      name = "rowlett";
      host = "rowlett";
      profile = "rowlett.remmina";
      port = 3389;
      desktop = 3;
      icon = "computer";
      tailnet = true;
    }
    {
      name = "mac-studio";
      host = "mac-studio";
      profile = "mac-studio.remmina";
      port = 5900;
      desktop = 0;
      icon = "computer-apple";
      tailnet = false;
    }
  ];

  # Switch to the host's desktop, then connect unless a session to it is
  # already up (Remmina would otherwise open a second one).
  remoteSession = pkgs.writeShellApplication {
    name = "remote-session";
    runtimeInputs = with pkgs; [
      getent
      gawk
      gnugrep
      iproute2
      kdePackages.qttools
      remmina
    ];
    text = ''
      host=$1 profile=$2 port=$3 desktop=''${4:-0}
      if [ "$desktop" -gt 0 ]; then
        qdbus org.kde.KWin /KWin setCurrentDesktop "$desktop" >/dev/null
      fi
      ip=$(getent ahostsv4 "$host" | awk 'NR == 1 { print $1 }')
      if [ -n "$ip" ] && ss -Htn state established "( dport = :$port )" | grep -qF " $ip:$port"; then
        exit 0
      fi
      exec remmina -c "$HOME/.local/share/remmina/$profile"
    '';
  };

  # ssh into a tailnet host in a new tab of the most recent kitty window
  # (found by its remote-control socket, see programs.kitty below), raised to
  # the front; a fresh kitty window if none is listening. --hold keeps the
  # tab open if ssh fails, so the error stays readable.
  sshTab = pkgs.writeShellApplication {
    name = "ssh-tab";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      iproute2
      kdotool
      kitty
    ];
    text = ''
      host=$1
      sock=$(ss -xlH | grep -o '@kitty-[0-9]\+' | sort -t- -k2 -n | tail -n1 || true)
      if [ -n "$sock" ] && kitty @ --to "unix:$sock" launch --type=tab --hold \
          --tab-title "$host" ssh "$host" >/dev/null; then
        # `kdotool search --pid` doesn't filter here, so match PIDs by hand.
        pid=''${sock#@kitty-}
        for w in $(kdotool search --class kitty 2>/dev/null); do
          if [ "$(kdotool getwindowpid "$w" 2>/dev/null)" = "$pid" ]; then
            kdotool windowactivate "$w"
            break
          fi
        done
        exit 0
      fi
      exec kitty --hold --title "$host" ssh "$host"
    '';
  };

  metadata = builtins.toJSON {
    KPlugin = {
      Id = id;
      Name = "Tailnet";
      Description = "Tailscale status and remote desktop quick connect";
      Icon = "network-vpn";
      Authors = [ { Name = "Christopher Miller"; } ];
      License = "MIT";
      Version = "1.0";
    };
    KPackageStructure = "Plasma/Applet";
    X-Plasma-API-Minimum-Version = "6.0";
  };

  mainQml = ''
    import QtQuick
    import QtQuick.Layouts
    import org.kde.plasma.plasmoid
    import org.kde.plasma.components as PlasmaComponents
    import org.kde.plasma.plasma5support as P5Support
    import org.kde.kirigami as Kirigami

    PlasmoidItem {
        id: root

        readonly property string statusCmd: "/run/current-system/sw/bin/tailscale status --json"
        readonly property var remotes: ${builtins.toJSON remotes}

        property var status: null
        readonly property bool connected: status !== null && status.BackendState === "Running"
        readonly property string selfName: connected ? shortName(status.Self.DNSName) : ""
        readonly property var exitNode: {
            if (!connected) return null;
            const peers = Object.values(status.Peer || {});
            return peers.find(p => p.ExitNode) || null;
        }
        readonly property var peers: {
            if (!connected) return [];
            return Object.values(status.Peer || {})
                .map(p => ({ name: shortName(p.DNSName), os: p.OS, online: p.Online }))
                .sort((a, b) => (b.online - a.online) || a.name.localeCompare(b.name));
        }

        function shortName(dns) {
            return (dns || "").split(".")[0];
        }
        function isOnline(host) {
            return peers.some(p => p.name === host && p.online);
        }
        function run(cmd) {
            root.expanded = false;
            exec.connectSource(cmd);
        }

        preferredRepresentation: compactRepresentation
        onExpandedChanged: {
            if (expanded) {
                poll.disconnectSource(statusCmd);
                poll.connectSource(statusCmd);
            }
        }
        toolTipMainText: "Tailscale"
        toolTipSubText: connected
            ? "Connected as " + selfName + (exitNode ? " · exit node " + shortName(exitNode.DNSName) : "")
            : "Not connected"

        P5Support.DataSource {
            id: poll
            engine: "executable"
            connectedSources: [root.statusCmd]
            interval: 10000
            onNewData: (sourceName, data) => {
                if (data["exit code"] !== 0) {
                    root.status = null;
                    return;
                }
                try {
                    root.status = JSON.parse(data.stdout);
                } catch (e) {
                    root.status = null;
                }
            }
        }

        P5Support.DataSource {
            id: exec
            engine: "executable"
            connectedSources: []
            onNewData: (sourceName, data) => disconnectSource(sourceName)
        }

        // The Tailscale mark: a 3x3 grid of dots, middle row and bottom
        // centre lit. Text colour when connected, mauve with an exit node,
        // red when down.
        compactRepresentation: MouseArea {
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
            Layout.minimumWidth: height

            Grid {
                id: mark
                anchors.centerIn: parent
                readonly property real dot: Math.round(Math.min(parent.width, parent.height) * 0.16)
                columns: 3
                spacing: Math.round(dot * 0.55)
                readonly property color lit: !root.connected ? Kirigami.Theme.negativeTextColor
                    : root.exitNode ? Kirigami.Theme.highlightColor
                    : Kirigami.Theme.textColor
                Repeater {
                    model: [0, 0, 0, 1, 1, 1, 0, 1, 0]
                    Rectangle {
                        required property int modelData
                        width: mark.dot
                        height: mark.dot
                        radius: mark.dot / 2
                        color: mark.lit
                        opacity: modelData ? 1 : 0.3
                    }
                }
            }
        }

        component Dot: Rectangle {
            property bool on: false
            implicitWidth: Kirigami.Units.smallSpacing * 2
            implicitHeight: implicitWidth
            radius: width / 2
            color: on ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
        }

        component SectionLabel: PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            leftPadding: Kirigami.Units.smallSpacing
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
        }

        fullRepresentation: ColumnLayout {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                Kirigami.Heading {
                    level: 4
                    text: "Tailscale"
                    Layout.fillWidth: true
                }
                Dot { on: root.connected }
                PlasmaComponents.Label {
                    text: root.connected ? root.selfName : "Not connected"
                    opacity: 0.8
                }
            }
            PlasmaComponents.Label {
                visible: root.exitNode !== null
                Layout.leftMargin: Kirigami.Units.smallSpacing
                text: root.exitNode ? "Exit node: " + root.shortName(root.exitNode.DNSName) : ""
                color: Kirigami.Theme.highlightColor
            }

            Kirigami.Separator { Layout.fillWidth: true }
            SectionLabel { text: "Remote desktops" }

            Repeater {
                model: root.remotes
                PlasmaComponents.ItemDelegate {
                    required property var modelData
                    Layout.fillWidth: true
                    icon.name: modelData.icon
                    text: modelData.name
                    onClicked: root.run(["${remoteSession}/bin/remote-session",
                        modelData.host, modelData.profile, modelData.port, modelData.desktop].join(" "))
                    Dot {
                        visible: modelData.tailnet
                        on: root.isOnline(modelData.host)
                        anchors.right: parent.right
                        anchors.rightMargin: Kirigami.Units.largeSpacing
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
            }
            SectionLabel { text: "Devices" }

            // Online devices open an ssh session in a kitty tab.
            Repeater {
                model: root.peers
                PlasmaComponents.ItemDelegate {
                    required property var modelData
                    Layout.fillWidth: true
                    topPadding: 2
                    bottomPadding: 2
                    enabled: modelData.online
                    opacity: modelData.online ? 1 : 0.45
                    onClicked: root.run("${sshTab}/bin/ssh-tab " + modelData.name)
                    contentItem: RowLayout {
                        Dot { on: modelData.online }
                        PlasmaComponents.Label {
                            text: modelData.name
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        PlasmaComponents.Label {
                            text: modelData.os
                            opacity: 0.6
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }
                }
            }
            Kirigami.Separator {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
            }
            // Trayscale keeps running for exit nodes and up/down; its tray
            // icon is tucked away in plasma.nix in favour of this menu.
            PlasmaComponents.ItemDelegate {
                Layout.fillWidth: true
                icon.name: "configure"
                text: "Exit nodes & settings…"
                onClicked: root.run("${pkgs.trayscale}/bin/trayscale")
            }

            Item {
                implicitHeight: Kirigami.Units.smallSpacing
                Layout.fillHeight: true
            }
        }
    }
  '';
in
{
  # Remote control for ssh-tab: a per-instance socket, local user only.
  programs.kitty.settings = {
    allow_remote_control = "socket-only";
    listen_on = "unix:@kitty-{kitty_pid}";
  };

  xdg.dataFile."plasma/plasmoids/${id}".source =
    pkgs.runCommand "plasma-tailnet-menu"
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
