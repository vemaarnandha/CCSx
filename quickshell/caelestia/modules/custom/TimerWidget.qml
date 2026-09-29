// TimerWidget.qml — Countdown with ROTARY DIAL for caelestia-shell + Hyprland
// Live location: ~/.config/quickshell/caelestia/modules/custom/TimerWidget.qml
//
// Thin view over TimerService (modules/custom/TimerService.qml): all timer
// state, the ticking engine, persistence and notifications live in the
// app-lifetime singleton, so this widget can be destroyed/recreated by the
// dashboard Loader without losing anything.
//
// Usage: TAP or DRAG (rotate) on the circle.
//   Full circle = 60 minutes. Angle from 12 o'clock, clockwise:
//   right (90°) = 15 min, bottom (180°) = 30 min, left (270°) = 45 min, top = 60 min.
//   (Fully mouse-driven — no keyboard needed.)

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    radius: Tokens.rounding.large
    color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
    implicitWidth: 300
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    // Angle from mouse position relative to the dial (0 = 12 o'clock, clockwise).
    // Dead zone in the center (r < 28) → return the current angle (ignore).
    function angleAt(mx: real, my: real): real {
        const dx = mx - dial.width / 2;
        const dy = my - dial.height / 2;
        if (dx * dx + dy * dy < 28 * 28)
            return TimerService.dialAngle;
        return (Math.atan2(dx, -dy) * 180 / Math.PI + 360) % 360;
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
                text: TimerService.isRunning ? qsTr("running") : TimerService.isFinished ? qsTr("done") : qsTr("spin the dial")
                color: TimerService.isFinished ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            }
        }

        // ── Rotary dial ──
        Item {
            id: dial
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 220
            implicitHeight: 220

            property real trackR: 92   // track circle radius
            property real lineW: 14    // ring thickness

            Canvas {
                id: ring
                anchors.fill: parent

                // Repaint on remaining-time / status changes.
                Connections {
                    target: TimerService
                    function onDialAngleChanged(): void { ring.requestPaint(); }
                    function onIsFinishedChanged(): void { ring.requestPaint(); }
                    function onIsRunningChanged(): void { ring.requestPaint(); }
                }
                Component.onCompleted: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const cx = width / 2, cy = height / 2;
                    const R = dial.trackR, lw = dial.lineW;
                    const track = Colours.palette.m3surfaceContainerHighest.toString();
                    const prog = (TimerService.isFinished ? Colours.palette.m3error : Colours.palette.m3primary).toString();
                    const tick = Colours.palette.m3onSurfaceVariant.toString();

                    // Full track
                    ctx.beginPath();
                    ctx.arc(cx, cy, R, 0, Math.PI * 2);
                    ctx.lineWidth = lw;
                    ctx.strokeStyle = track;
                    ctx.stroke();

                    // Tick every 5 minutes (longer every 15 minutes)
                    ctx.lineWidth = 2;
                    ctx.strokeStyle = tick;
                    for (let m = 0; m < 60; m += 5) {
                        const a = m * 6 * Math.PI / 180;
                        const len = (m % 15 === 0) ? 12 : 7;
                        const oR = R - lw / 2 - 2;
                        ctx.beginPath();
                        ctx.moveTo(cx + (oR - len) * Math.sin(a), cy - (oR - len) * Math.cos(a));
                        ctx.lineTo(cx + oR * Math.sin(a), cy - oR * Math.cos(a));
                        ctx.stroke();
                    }

                    // Labels 15 / 30 / 45 / 60
                    ctx.fillStyle = tick;
                    ctx.font = "12px sans-serif";
                    ctx.textAlign = "center";
                    ctx.textBaseline = "middle";
                    ctx.fillText("60", cx, cy - R + 26);
                    ctx.fillText("15", cx + R - 26, cy);
                    ctx.fillText("30", cx, cy + R - 26);
                    ctx.fillText("45", cx - R + 26, cy);

                    // Progress arc from 12 o'clock, clockwise
                    if (TimerService.progress > 0) {
                        ctx.beginPath();
                        ctx.arc(cx, cy, R, -Math.PI / 2, -Math.PI / 2 + TimerService.progress * Math.PI * 2);
                        ctx.lineWidth = lw;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = prog;
                        ctx.stroke();
                    }

                    // Knob at the remaining-time position
                    const ka = TimerService.dialAngle * Math.PI / 180;
                    const kx = cx + R * Math.sin(ka), ky = cy - R * Math.cos(ka);
                    ctx.beginPath();
                    ctx.arc(kx, ky, 10, 0, Math.PI * 2);
                    ctx.fillStyle = prog;
                    ctx.fill();
                    ctx.beginPath();
                    ctx.arc(kx, ky, 4, 0, Math.PI * 2);
                    ctx.fillStyle = Colours.palette.m3surfaceContainerHigh.toString();
                    ctx.fill();
                }
            }

            // MM:SS in the dial center
            Column {
                anchors.centerIn: parent
                spacing: 0
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: TimerService.fmt(TimerService.remainingSeconds)
                    font: Tokens.font.clock.size(34).weight(Font.DemiBold).build()
                    color: TimerService.isFinished ? Colours.palette.m3error : Colours.palette.m3onSurface
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.round(TimerService.remainingSeconds / 60) + qsTr(" min")
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            // Set time via tap / drag (only while stopped).
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !TimerService.isRunning
                onPressed: mouse => TimerService.setFromAngle(root.angleAt(mouse.x, mouse.y))
                onPositionChanged: mouse => {
                    if (pressed)
                        TimerService.setFromAngle(root.angleAt(mouse.x, mouse.y));
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Tap / drag the dial — max 60 min")
            color: Colours.palette.m3onSurfaceVariant
        }

        // Quick presets + notification test
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            Repeater {
                model: [
                    { label: "5m", secs: 5 * 60 },
                    { label: "15m", secs: 15 * 60 },
                    { label: "25m", secs: 25 * 60 },
                    { label: "test 10s", secs: 10 }
                ]
                delegate: StyledRect {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: Tokens.rounding.full
                    color: TimerService.totalSeconds === modelData.secs
                        ? Colours.palette.m3primary
                        : Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)

                    StyledText {
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: TimerService.totalSeconds === parent.modelData.secs
                            ? Colours.palette.m3onPrimary
                            : Colours.palette.m3onSurface
                    }
                    StateLayer {
                        anchors.fill: parent
                        onClicked: TimerService.setDuration(parent.modelData.secs)
                        color: TimerService.totalSeconds === parent.modelData.secs
                            ? Colours.palette.m3onPrimary
                            : Colours.palette.m3onSurface
                    }
                }
            }
        }

        // Start / Pause / Reset controls
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 38
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
                implicitHeight: 38
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
