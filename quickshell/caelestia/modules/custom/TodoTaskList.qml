// TodoTaskList.qml — one filtered task list (adapted from end-4/dots-hyprland
// TaskList.qml, GPL-3.0): renders a projection array of the service list.
// Each entry: { "text", "done", "originalIndex" } — actions use originalIndex
// so they hit the right item in TodoService.list.

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property var taskList
    required property string emptyIcon
    required property string emptyText

    ListView {
        anchors.fill: parent
        clip: true
        spacing: Tokens.spacing.small
        boundsBehavior: Flickable.StopAtBounds
        model: (root.taskList ?? []).length

        delegate: StyledRect {
            required property int index
            readonly property var entry: (root.taskList ?? [])[index] ?? ({ text: "", done: false, originalIndex: -1 })

            width: ListView.view.width
            implicitHeight: 48
            radius: Tokens.rounding.medium
            color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.small
                anchors.rightMargin: Tokens.padding.small
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: entry.done ? "check_circle" : "radio_button_unchecked"
                    fill: entry.done ? 1 : 0
                    color: entry.done ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: TodoService.setDone(entry.originalIndex, !entry.done)
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: entry.text
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    color: entry.done ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                    font.strikeout: entry.done
                    opacity: entry.done ? 0.6 : 1.0
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: TodoService.setDone(entry.originalIndex, !entry.done)
                    }
                }

                MaterialIcon {
                    text: "delete"
                    color: Colours.palette.m3error
                    fontStyle: Tokens.font.icon.small
                    opacity: delHover.containsMouse ? 1.0 : 0.6
                    MouseArea {
                        id: delHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: TodoService.deleteItem(entry.originalIndex)
                    }
                }
            }
        }
    }

    // Empty placeholder (icon + text, centered).
    Column {
        anchors.centerIn: parent
        visible: (root.taskList ?? []).length === 0
        spacing: Tokens.spacing.small

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.emptyIcon
            fontStyle: Tokens.font.icon.extraLarge
            color: Colours.palette.m3onSurfaceVariant
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.emptyText
            color: Colours.palette.m3onSurfaceVariant
        }
    }
}
