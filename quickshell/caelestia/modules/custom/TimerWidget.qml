// TimerWidget.qml — Pomodoro card (Opsi 1) for caelestia-shell + Hyprland
// Live location: ~/.config/quickshell/caelestia/modules/custom/TimerWidget.qml
//
// Thin view over TimerService (modules/custom/TimerService.qml): session
// logic, the ticking engine, persistence and notifications live in the
// app-lifetime singleton. Fully mouse-driven — no keyboard needed.

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

    // Resolve the urgency level to theme colors (theme stays in the view).
    function ringColor(): color {
        if (TimerService.urgency === 2)
            return Colours.palette.m3error;
        if (TimerService.urgency === 1)
            return Colours.palette.m3tertiary;
        return Colours.palette.m3primary;
    }

    // Pill chip button, reused for modes + adjust steps.
    // With sub text it renders two lines (name + detail); without, one line.
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

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        // Title + status
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
                text: TimerService.isRunning ? qsTr("running") : TimerService.isFinished ? qsTr("done") : qsTr("ready")
                color: TimerService.isFinished ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            }
        }

        // ── Ring hero ──
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

                    // Track
                    ctx.beginPath();
                    ctx.arc(cx, cy, R, 0, Math.PI * 2);
                    ctx.lineWidth = lw;
                    ctx.strokeStyle = track;
                    ctx.stroke();

                    // Progress arc from 12 o'clock, clockwise
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

            // Time + mode in the center
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
        }

        // ── Session dots ──
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

        // ── Mode chips ──
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

        // ── Custom adjust (minutes) ──
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

        // Start / Pause / Reset controls
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: Tokens.rounding.full
                color: Colours.palette.m3primary
                StyledText {
                    anchors.centerIn: parent
                    text: TimerService.isRunning ? qsTr("Pause") : qsTr("Start")
                    color: Colours.palette.m3onPrimary
                }
                StateLayer {
                    anchors.fill: parent
                    onClicked: {
                        if (TimerService.isRunning)
                            TimerService.pause();
                        else
                            TimerService.start();
                    }
                    color: Colours.palette.m3onPrimary
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: Tokens.rounding.full
                color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                StyledText {
                    anchors.centerIn: parent
                    text: qsTr("Reset")
                    color: Colours.palette.m3onSurface
                }
                StateLayer {
                    anchors.fill: parent
                    onClicked: TimerService.reset()
                    color: Colours.palette.m3onSurface
                }
            }
        }
    }
}
