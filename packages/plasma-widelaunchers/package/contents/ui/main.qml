/*
    Wide Launchers: a row of app launchers for the right end of the panel.

    - Room on the panel:   one icon per launcher.
    - Panel squeezes us:   one icon; click opens a menu with every launcher.
      Detection rides on the panel layout: minimum width is one slot,
      preferred width is always every slot, so being handed less than the
      preferred width means "crowded" and getting it back means "room again".
    - No wide screen:      HiddenStatus + zero size (the panel then drops the
      applet from its layout, so no gap). Every connected screen counts.
    - Running app:         a highlight bar on the panel edge under its icon.
*/
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

import "logic.js" as Logic

PlasmoidItem {
    id: root

    readonly property var launchers: Plasmoid.configuration.launchers
    readonly property int count: launchers.length
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    // Qt.application.screens is referenced directly so plugging or unplugging
    // a screen (or changing its scale) re-evaluates this binding.
    readonly property bool wide: Logic.hasWideScreen(
        Qt.application.screens.map(s => s.width), Plasmoid.configuration.minScreenWidth)

    preferredRepresentation: fullRepresentation
    Plasmoid.status: wide && count > 0 ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ---- Task model: one row per launcher, or per running app instead ----

    property int revision: 0

    TaskManager.TasksModel {
        id: tasksModel
        filterByVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
        groupMode: TaskManager.TasksModel.GroupApplications
        separateLaunchers: false
        launchInPlace: true
        hideActivatedLaunchers: true
        launcherList: root.launchers.map(id => "applications:" + id + ".desktop")

        onDataChanged: root.revision++
        onRowsInserted: root.revision++
        onRowsRemoved: root.revision++
        onModelReset: root.revision++
    }

    // Plain-object snapshot of the model, for Logic.appState.
    readonly property var rows: {
        revision; // re-evaluate on every model change
        const atm = TaskManager.AbstractTasksModel;
        const out = [];
        for (let i = 0; i < tasksModel.count; ++i) {
            const idx = tasksModel.makeModelIndex(i);
            out.push({
                AppId: tasksModel.data(idx, atm.AppId),
                AppName: tasksModel.data(idx, atm.AppName),
                IsLauncher: tasksModel.data(idx, atm.IsLauncher) === true,
                IsGroupParent: tasksModel.data(idx, atm.IsGroupParent) === true,
                decoration: tasksModel.data(idx, Qt.DecorationRole),
            });
        }
        return out;
    }
    readonly property var states: launchers.map(id => Logic.appState(rows, id))

    function activate(launcherIndex) {
        const state = states[launcherIndex];
        if (!state || state.row < 0) {
            return;
        }
        const row = rows[state.row];
        if (!state.running) {
            tasksModel.requestNewInstance(tasksModel.makeModelIndex(state.row));
        } else {
            // Focus the existing window (first window of a group) rather than
            // starting another instance.
            tasksModel.requestActivate(row.IsGroupParent
                ? tasksModel.makeModelIndex(state.row, 0)
                : tasksModel.makeModelIndex(state.row));
        }
    }

    function nameOf(i) {
        const s = states[i];
        return s && s.row >= 0 ? rows[s.row].AppName : launchers[i];
    }
    function iconOf(i) {
        const s = states[i];
        return s && s.row >= 0 && rows[s.row].decoration ? rows[s.row].decoration : "application-x-executable";
    }

    // ---- Presentation ----

    component RunningBar: Rectangle {
        property bool shown: false
        visible: shown
        width: Math.round(parent.width / 2)
        height: Math.max(2, Math.round(Kirigami.Units.devicePixelRatio * 3))
        radius: height / 2
        color: Kirigami.Theme.highlightColor
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: Plasmoid.location === PlasmaCore.Types.TopEdge ? undefined : parent.bottom
        anchors.top: Plasmoid.location === PlasmaCore.Types.TopEdge ? parent.top : undefined
    }

    fullRepresentation: Item {
        id: full

        readonly property real slot: root.vertical ? width : height
        readonly property string mode: Logic.displayMode(root.wide, root.vertical ? height : width, slot, root.count)

        Layout.minimumWidth: mode === "hidden" ? 0 : slot
        Layout.preferredWidth: mode === "hidden" ? 0 : slot * root.count
        Layout.maximumWidth: Layout.preferredWidth
        Layout.minimumHeight: root.vertical ? Layout.minimumWidth : -1
        Layout.preferredHeight: root.vertical ? Layout.preferredWidth : -1
        Layout.maximumHeight: root.vertical ? Layout.preferredWidth : -1

        Row {
            visible: full.mode === "full"
            anchors.fill: parent

            Repeater {
                model: root.count

                delegate: Item {
                    id: launcher
                    required property int index
                    width: full.slot
                    height: full.slot

                    Kirigami.Icon {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        source: root.iconOf(launcher.index)
                        active: mouse.containsMouse
                    }
                    RunningBar {
                        shown: root.states[launcher.index]?.running ?? false
                    }
                    PlasmaCore.ToolTipArea {
                        anchors.fill: parent
                        mainText: root.nameOf(launcher.index)
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.activate(launcher.index)
                    }
                }
            }
        }

        Item {
            id: collapsed
            visible: full.mode === "collapsed"
            width: full.slot
            height: full.slot
            anchors.centerIn: parent

            Kirigami.Icon {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                source: "dialog-messages"
                active: collapsedMouse.containsMouse
            }
            RunningBar {
                shown: Logic.anyRunning(root.states)
            }
            PlasmaCore.ToolTipArea {
                anchors.fill: parent
                mainText: root.launchers.map((_, i) => root.nameOf(i)).join(", ")
            }
            MouseArea {
                id: collapsedMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    menu.clearMenuItems();
                    for (let i = 0; i < root.count; ++i) {
                        const item = menu.newMenuItem(menu);
                        const launcherIndex = i;
                        item.text = root.nameOf(i);
                        item.icon = root.iconOf(i);
                        item.clicked.connect(() => root.activate(launcherIndex));
                        menu.addMenuItem(item);
                    }
                    menu.openRelative();
                }
            }

            PlasmaExtras.Menu {
                id: menu
                visualParent: collapsed
                placement: {
                    switch (Plasmoid.location) {
                    case PlasmaCore.Types.LeftEdge:
                        return PlasmaExtras.Menu.RightPosedTopAlignedPopup;
                    case PlasmaCore.Types.TopEdge:
                        return PlasmaExtras.Menu.BottomPosedLeftAlignedPopup;
                    case PlasmaCore.Types.RightEdge:
                        return PlasmaExtras.Menu.LeftPosedTopAlignedPopup;
                    default:
                        return PlasmaExtras.Menu.TopPosedLeftAlignedPopup;
                    }
                }
            }
        }
    }
}
