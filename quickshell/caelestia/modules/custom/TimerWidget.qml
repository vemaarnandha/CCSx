// TimerWidget.qml — Countdown with ROTARY DIAL for caelestia-shell + Hyprland
// Live location: ~/.config/quickshell/caelestia/modules/custom/TimerWidget.qml
//
// Usage: TAP or DRAG (rotate) on the circle.
//   Full circle = 60 minutes. Angle from 12 o'clock, clockwise:
//   right (90°) = 15 min, bottom (180°) = 30 min, left (270°) = 45 min, top = 60 min.
//   (Fully mouse-driven — no keyboard needed.)
//
// Notifications: via `notify-send` → picked up by Caelestia's built-in NotificationDaemon.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    radius: Tokens.rounding.large
    color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
    implicitWidth: 300
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    // ── Timer state ──
    property int totalSeconds: 25 * 60
    property int remainingSeconds: 25 * 60
    property bool isRunning: false
    property bool isFinished: false

    // Clamp range: 10 seconds (test chip) to 60 minutes (full dial).
    // The dial itself still snaps 1..60 minutes via setFromAngle().
    readonly property int minSeconds: 10
    readonly property int maxSeconds: 60 * 60

    // Ratio 0..1 for the progress arc.
    readonly property real progress: totalSeconds > 0 ? remainingSeconds / totalSeconds : 0
    // Knob angle from 12 o'clock, clockwise: 1 second = 0.1°.
    readonly property real dialAngle: (remainingSeconds / 10) % 360

    // Format MM:SS, e.g. 1500 → "25:00"
    function fmt(s: int): string {
        const m = Math.floor(Math.max(0, s) / 60);
        const sec = Math.max(0, s) % 60;
        return (m < 10 ? "0" + m : "" + m) + ":" + (sec < 10 ? "0" + sec : "" + sec);
    }

    function setDuration(seconds: int): void {
        countdown.stop();
        const clamped = Math.min(root.maxSeconds, Math.max(root.minSeconds, seconds));
        root.totalSeconds = clamped;
        root.remainingSeconds = clamped;
        root.isRunning = false;
        root.isFinished = false;
    }

    // Convert dial angle (0..360) → minutes (snap per minute, 0 = 60).
    function setFromAngle(angleDeg: real): void {
        let mins = Math.round(angleDeg / 6);
        if (mins <= 0)
            mins = 60;
        mins = Math.min(60, Math.max(1, mins));
        root.setDuration(mins * 60);
    }

    // Angle from mouse position relative to the dial (0 = 12 o'clock, clockwise).
    // Dead zone in the center (r < 28) → return the current angle (ignore).
    function angleAt(mx: real, my: real): real {
        const dx = mx - dial.width / 2;
        const dy = my - dial.height / 2;
        if (dx * dx + dy * dy < 28 * 28)
            return root.dialAngle;
        return (Math.atan2(dx, -dy) * 180 / Math.PI + 360) % 360;
    }

    function start(): void {
        if (root.remainingSeconds <= 0)
            root.remainingSeconds = root.totalSeconds;
        root.isFinished = false;
        root.isRunning = true;
        countdown.start();
    }

    function pause(): void {
        root.isRunning = false;
        countdown.stop();
    }

    function reset(): void {
        countdown.stop();
        root.remainingSeconds = root.totalSeconds;
        root.isRunning = false;
        root.isFinished = false;
    }

    // Requires the `libnotify` package (Arch: `sudo pacman -S libnotify`).
    function notifyDone(): void {
        Quickshell.execDetached([
            "notify-send", "-a", "caelestia-shell",
            "-u", "critical",
            "Timer done",
            "Time is up — take a break"
        ]);
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            if (root.remainingSeconds > 0)
                root.remainingSeconds -= 1;
            if (root.remainingSeconds <= 0) {
                countdown.stop();
                root.isRunning = false;
                root.isFinished = true;
                root.notifyDone();
            }
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
                text: root.isRunning ? qsTr("running") : root.isFinished ? qsTr("done") : qsTr("spin the dial")
                color: root.isFinished ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
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
                    target: root
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
                    const prog = (root.isFinished ? Colours.palette.m3error : Colours.palette.m3primary).toString();
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
                    if (root.progress > 0) {
                        ctx.beginPath();
                        ctx.arc(cx, cy, R, -Math.PI / 2, -Math.PI / 2 + root.progress * Math.PI * 2);
                        ctx.lineWidth = lw;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = prog;
                        ctx.stroke();
                    }

                    // Knob at the remaining-time position
                    const ka = root.dialAngle * Math.PI / 180;
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
                    text: root.fmt(root.remainingSeconds)
                    font: Tokens.font.clock.size(34).weight(Font.DemiBold).build()
                    color: root.isFinished ? Colours.palette.m3error : Colours.palette.m3onSurface
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.round(root.remainingSeconds / 60) + qsTr(" min")
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            // Set time via tap / drag (only while stopped).
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !root.isRunning
                onPressed: mouse => root.setFromAngle(root.angleAt(mouse.x, mouse.y))
                onPositionChanged: mouse => {
                    if (pressed)
                        root.setFromAngle(root.angleAt(mouse.x, mouse.y));
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
                    color: root.totalSeconds === modelData.secs
                        ? Colours.palette.m3primary
                        : Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)

                    StyledText {
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: root.totalSeconds === parent.modelData.secs
                            ? Colours.palette.m3onPrimary
                            : Colours.palette.m3onSurface
                    }
                    StateLayer {
                        anchors.fill: parent
                        onClicked: root.setDuration(parent.modelData.secs)
                        color: root.totalSeconds === parent.modelData.secs
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
                    text: root.isRunning ? qsTr("Pause") : qsTr("Start")
                    color: Colours.palette.m3onPrimary
                }
                StateLayer {
                    anchors.fill: parent
                    onClicked: {
                        if (root.isRunning)
                            root.pause();
                        else
                            root.start();
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
                    onClicked: root.reset()
                    color: Colours.palette.m3onSurface
                }
            }
        }
    }
}
