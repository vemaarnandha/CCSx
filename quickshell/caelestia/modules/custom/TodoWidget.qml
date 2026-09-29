// TodoWidget.qml — tabbed todo card (adapted from end-4/dots-hyprland
// TodoWidget.qml, GPL-3.0): Unfinished/Done tabs, FAB + add dialog.
// Data lives in TodoService (single source of truth); this file only
// renders projections and forwards actions. Fully mouse-driven, and the
// text field works now that the dashboard accepts keyboard focus.

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    radius: Tokens.rounding.large
    color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
    implicitWidth: 360
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    property int currentTab: 0 // 0 = Unfinished, 1 = Done
    property bool showAddDialog: false

    // Projections of the service list (end4 pattern: map + originalIndex).
    // Guard ?? [] so first frames before the singleton loads don't spam WARN.
    readonly property var unfinishedTasks: (TodoService.list ?? []).map(function(item, i) {
        return { text: item.text, done: item.done, originalIndex: i };
    }).filter(function(item) {
        return !item.done;
    })
    readonly property var doneTasks: (TodoService.list ?? []).map(function(item, i) {
        return { text: item.text, done: item.done, originalIndex: i };
    }).filter(function(item) {
        return item.done;
    })

    // Esc closes the dialog.
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape && root.showAddDialog) {
            root.showAddDialog = false;
            event.accepted = true;
        }
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "checklist"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.medium
            }
            StyledText {
                text: qsTr("Tasks")
                font: Tokens.font.title.small
                color: Colours.palette.m3onSurface
                Layout.fillWidth: true
            }
            StyledText {
                text: qsTr("%1 left").arg((root.unfinishedTasks ?? []).length)
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        // Unfinished / Done tab chips
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 32
                radius: Tokens.rounding.full
                color: root.currentTab === 0
                    ? Colours.palette.m3primary
                    : Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                StyledText {
                    anchors.centerIn: parent
                    text: qsTr("Unfinished")
                    color: root.currentTab === 0 ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                }
                StateLayer {
                    anchors.fill: parent
                    onClicked: root.currentTab = 0
                    color: root.currentTab === 0 ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                }
            }
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 32
                radius: Tokens.rounding.full
                color: root.currentTab === 1
                    ? Colours.palette.m3primary
                    : Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                StyledText {
                    anchors.centerIn: parent
                    text: qsTr("Done")
                    color: root.currentTab === 1 ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                }
                StateLayer {
                    anchors.fill: parent
                    onClicked: root.currentTab = 1
                    color: root.currentTab === 1 ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                }
            }
        }

        // Lists (fixed height so the card never jumps between tabs).
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 300

            TodoTaskList {
                anchors.fill: parent
                visible: root.currentTab === 0
                taskList: root.unfinishedTasks
                emptyIcon: "check_circle"
                emptyText: qsTr("Nothing here!")
            }
            TodoTaskList {
                anchors.fill: parent
                visible: root.currentTab === 1
                taskList: root.doneTasks
                emptyIcon: "checklist"
                emptyText: qsTr("Finished tasks will go here")
            }

            // + FAB (bottom-right, above the list).
            StyledRect {
                id: fab
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Tokens.spacing.small
                implicitWidth: 48
                implicitHeight: 48
                radius: Tokens.rounding.full
                color: Colours.palette.m3primary
                MaterialIcon {
                    anchors.centerIn: parent
                    text: "add"
                    color: Colours.palette.m3onPrimary
                    fontStyle: Tokens.font.icon.medium
                }
                StateLayer {
                    anchors.fill: parent
                    onClicked: root.showAddDialog = true
                    color: Colours.palette.m3onPrimary
                }
            }
        }

        // Clear-completed link under the Done tab.
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: root.currentTab === 1 && (root.doneTasks ?? []).length > 0
            text: qsTr("Clear completed")
            color: Colours.palette.m3error
            font.underline: true
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: TodoService.clearDone()
            }
        }
    }

    // ── Add dialog (scrim + centered card) ──
    Item {
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.showAddDialog ? 1 : 0

        Behavior on opacity {
            Anim {}
        }

        StyledRect {
            anchors.fill: parent
            radius: root.radius
            color: Colours.palette.m3scrim
            opacity: 0.6
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.showAddDialog = false
            }
        }

        StyledRect {
            id: dialog
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Tokens.padding.large
            implicitHeight: dialogLayout.implicitHeight + Tokens.padding.large * 2
            radius: Tokens.rounding.large
            color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)

            function addTask(): void {
                if (todoInput.text.length > 0) {
                    TodoService.addTask(todoInput.text);
                    todoInput.text = "";
                    root.showAddDialog = false;
                    root.currentTab = 0;
                }
            }

            ColumnLayout {
                id: dialogLayout
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.small

                StyledText {
                    text: qsTr("Add task")
                    font: Tokens.font.title.small
                    color: Colours.palette.m3onSurface
                }
                StyledTextField {
                    id: todoInput
                    Layout.fillWidth: true
                    placeholderText: qsTr("Task description")
                    focus: root.showAddDialog
                    onAccepted: dialog.addTask()
                }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Tokens.spacing.small

                    StyledRect {
                        implicitWidth: 84
                        implicitHeight: 36
                        radius: Tokens.rounding.full
                        color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                        StyledText {
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            color: Colours.palette.m3onSurface
                        }
                        StateLayer {
                            anchors.fill: parent
                            onClicked: root.showAddDialog = false
                            color: Colours.palette.m3onSurface
                        }
                    }
                    StyledRect {
                        implicitWidth: 84
                        implicitHeight: 36
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary
                        StyledText {
                            anchors.centerIn: parent
                            text: qsTr("Add")
                            color: Colours.palette.m3onPrimary
                        }
                        StateLayer {
                            anchors.fill: parent
                            onClicked: dialog.addTask()
                            color: Colours.palette.m3onPrimary
                        }
                    }
                }
            }
        }
    }
}
