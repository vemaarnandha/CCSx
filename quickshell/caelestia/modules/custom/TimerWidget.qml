// TimerWidget.qml — Pomodoro card + stopwatch (end4 UX adopted)
// Live location: ~/.config/quickshell/caelestia/modules/custom/TimerWidget.qml
//
// Thin view over TimerService (modules/custom/TimerService.qml): session
// logic, both engines, persistence and notifications live in the
// app-lifetime singleton. Fully mouse-driven — no keyboard needed.
// Adopted from end-4/dots-hyprland (GPL-3.0): 3-state Start/Pause/Resume
// label, cycle badge on the ring, stopwatch tab with laps.

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    radius: Tokens.rounding.large
    color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
    implicitWidth: 360
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    property int currentView: 0 // 0 = Pomodoro, 1 = Stopwatch

    // Resolve the urgency level to theme colors (theme stays in the view).
    function ringColor(): color {
        if (TimerService.urgency === 2)
            return Colours.palette.m3error;
        if (TimerService.urgency === 1)
            return Colours.palette.m3tertiary;
        return Colours.palette.m3primary;
    }

    // Small pill chip button, reused for modes + adjust steps + view tabs.
    component Chip: StyledRect {
        id: chip
        required property string label
        property string sub: ""
        required property var onTap
        required property bool highlighted
        Layout.fillWidth: true
        implicitHeight: chip.sub === "" ? 32 : 50
        radius: Tokens.rounding.full
        color: chip.highlighted
            ? Colours.palette.m3primary
            : Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)

        Column {
            anchors.centerIn: parent
            spacing: 0
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: chip.label
                color: chip.highlighted ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            }
            StyledText {
                visible: chip.sub !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                text: chip.sub
                font: Tokens.font.label.small
                color: chip.highlighted ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                opacity: 0.8
            }
        }
        StateLayer {
            anchors.fill: parent
            onClicked: chip.onTap()
            color: chip.highlighted ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
        }
    }

    // Rectangular control button (Start/Pause/Reset/Lap).
    component ControlButton: StyledRect {
        id: ctlBtn
        required property string label
        required property var onTap
        required property color bg
        required property color fg
        Layout.fillWidth: true
        implicitHeight: 40
        radius: Tokens.rounding.full
        color: ctlBtn.bg
        StyledText {
            anchors.centerIn: parent
            text: ctlBtn.label
            color: ctlBtn.fg
        }
        StateLayer {
            anchors.fill: parent
            onClicked: ctlBtn.onTap()
            color: ctlBtn.fg
        }
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        // Title + status + sound toggle
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "timer"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.medium
            }
            StyledText {
                text: qsTr("Timer")
                font: Tokens.font.title.small
                color: Colours.palette.m3onSurface
                Layout.fillWidth: true
            }
            StyledText {
                text: root.currentView === 1
                    ? (TimerService.swRunning ? qsTr("running") : qsTr("stopped"))
                    : TimerService.isRunning ? qsTr("running") : TimerService.isFinished ? qsTr("done") : qsTr("ready")
                color: TimerService.isFinished && root.currentView === 0 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            }
            MaterialIcon {
                text: TimerService.soundEnabled ? "volume_up" : "volume_off"
                color: TimerService.soundEnabled ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: TimerService.toggleSound()
                }
            }
        }

        // Pomodoro | Stopwatch view tabs
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Chip {
                label: qsTr("Pomodoro")
                highlighted: root.currentView === 0
                onTap: () => { root.currentView = 0; }
            }
            Chip {
                label: qsTr("Stopwatch")
                highlighted: root.currentView === 1
                onTap: () => { root.currentView = 1; }
            }
        }

        // ── Pomodoro view ──
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.currentView === 0
            spacing: Tokens.spacing.small

            // Ring hero
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 264
                implicitHeight: 264

                property real trackR: 112
                property real lineW: 16

                Canvas {
                    id: ring
                    anchors.fill: parent

                    Connections {
                        target: TimerService
                        function onProgressChanged(): void { ring.requestPaint(); }
                        function onUrgencyChanged(): void { ring.requestPaint(); }
                        function onIsFinishedChanged(): void { ring.requestPaint(); }
                    }
                    Component.onCompleted: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const cx = width / 2, cy = height / 2;
                        const R = parent.trackR, lw = parent.lineW;
                        const track = Colours.palette.m3surfaceContainerHighest.toString();
                        const prog = root.ringColor().toString();

                        ctx.beginPath();
                        ctx.arc(cx, cy, R, 0, Math.PI * 2);
                        ctx.lineWidth = lw;
                        ctx.strokeStyle = track;
                        ctx.stroke();

                        if (TimerService.progress > 0) {
                            ctx.beginPath();
                            ctx.arc(cx, cy, R, -Math.PI / 2, -Math.PI / 2 + TimerService.progress * Math.PI * 2);
                            ctx.lineWidth = lw;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = prog;
                            ctx.stroke();
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.extraSmall
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: TimerService.fmt(TimerService.remainingSeconds)
                        font: Tokens.font.clock.size(48).weight(Font.DemiBold).build()
                        color: TimerService.urgency === 2 ? Colours.palette.m3error : Colours.palette.m3onSurface
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: TimerService.mode === "short" ? qsTr("SHORT BREAK") : TimerService.mode === "long" ? qsTr("LONG BREAK") : qsTr("FOCUS")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                // Cycle badge (current cycle number, 1-based).
                StyledRect {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Tokens.spacing.small
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3secondaryContainer
                    StyledText {
                        anchors.centerIn: parent
                        text: TimerService.cycleDone + 1
                        color: Colours.palette.m3onSecondaryContainer
                    }
                }
            }

            // Session dots
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.spacing.small

                Repeater {
                    model: TimerService.cycleLength
                    delegate: StyledRect {
                        required property int index
                        implicitWidth: 12
                        implicitHeight: 12
                        radius: Tokens.rounding.full
                        color: index < TimerService.cycleDone
                            ? Colours.palette.m3primary
                            : Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                    }
                }
                StyledText {
                    text: qsTr("%1 of %2").arg(TimerService.cycleDone).arg(TimerService.cycleLength)
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            // Mode chips
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Chip {
                    label: qsTr("Focus")
                    sub: qsTr("%1 min").arg(TimerService.focusMinutes)
                    highlighted: TimerService.mode === "focus"
                    onTap: () => TimerService.setMode("focus")
                }
                Chip {
                    label: qsTr("Short")
                    sub: qsTr("%1 min").arg(TimerService.shortMinutes)
                    highlighted: TimerService.mode === "short"
                    onTap: () => TimerService.setMode("short")
                }
                Chip {
                    label: qsTr("Long")
                    sub: qsTr("%1 min").arg(TimerService.longMinutes)
                    highlighted: TimerService.mode === "long"
                    onTap: () => TimerService.setMode("long")
                }
            }

            // Custom adjust (minutes)
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Chip {
                    label: "−5m"
                    highlighted: false
                    onTap: () => TimerService.adjustSeconds(-5 * 60)
                }
                Chip {
                    label: "−1m"
                    highlighted: false
                    onTap: () => TimerService.adjustSeconds(-60)
                }
                Chip {
                    label: "+1m"
                    highlighted: false
                    onTap: () => TimerService.adjustSeconds(60)
                }
                Chip {
                    label: "+5m"
                    highlighted: false
                    onTap: () => TimerService.adjustSeconds(5 * 60)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                ControlButton {
                    // Three-state label (end4 pattern): Start → Pause → Resume.
                    label: TimerService.isRunning ? qsTr("Pause") : (TimerService.remainingSeconds === TimerService.totalSeconds ? qsTr("Start") : qsTr("Resume"))
                    bg: Colours.palette.m3primary
                    fg: Colours.palette.m3onPrimary
                    onTap: () => {
                        if (TimerService.isRunning)
                            TimerService.pause();
                        else
                            TimerService.start();
                    }
                }
                ControlButton {
                    label: qsTr("Reset")
                    bg: Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                    fg: Colours.palette.m3onSurface
                    onTap: () => TimerService.reset()
                }
            }
        }

        // ── Stopwatch view ──
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.currentView === 1
            spacing: Tokens.spacing.small

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: TimerService.swFmt(TimerService.swElapsedMs)
                font: Tokens.font.clock.size(44).weight(Font.DemiBold).build()
                color: Colours.palette.m3onSurface
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 4 * 36 + spacing * 4)
                clip: true
                spacing: Tokens.spacing.small
                boundsBehavior: Flickable.StopAtBounds
                model: TimerService.swLaps.length

                delegate: StyledRect {
                    required property int index
                    readonly property var lapMs: TimerService.swLaps[index]
                    width: ListView.view.width
                    implicitHeight: 36
                    radius: Tokens.rounding.medium
                    color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.small
                        anchors.rightMargin: Tokens.padding.small
                        StyledText {
                            text: qsTr("Lap %1").arg(index + 1)
                            color: Colours.palette.m3onSurfaceVariant
                            Layout.fillWidth: true
                        }
                        StyledText {
                            text: TimerService.swFmt(lapMs)
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurface
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: TimerService.swLaps.length === 0
                    text: qsTr("No laps yet")
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                ControlButton {
                    label: TimerService.swRunning ? qsTr("Pause") : qsTr("Start")
                    bg: Colours.palette.m3primary
                    fg: Colours.palette.m3onPrimary
                    onTap: () => TimerService.swToggle()
                }
                ControlButton {
                    label: qsTr("Lap")
                    bg: Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                    fg: Colours.palette.m3onSurface
                    onTap: () => TimerService.swLap()
                }
                ControlButton {
                    label: qsTr("Reset")
                    bg: Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                    fg: Colours.palette.m3onSurface
                    onTap: () => TimerService.swReset()
                }
            }
        }
    }
}
