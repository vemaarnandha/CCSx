// TimerService.qml — app-lifetime countdown engine behind the Focus tab timer.
//
// Singleton: it outlives the dashboard Loader (which destroys widgets every
// time the dashboard closes), so the countdown keeps ticking and its
// notification fires exactly on time even with the dashboard closed.
// Limit: the shell process itself must be running — nothing can notify
// after logout / shell kill. State persists in timer.json and resumes
// from wall-clock time after a full shell restart.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    property int totalSeconds: 25 * 60
    property int remainingSeconds: 25 * 60
    property bool isRunning: false
    property bool isFinished: false

    // Clamp range: 10 seconds (test chip) to 60 minutes (full dial).
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

    // Setting a duration stops a running timer on purpose:
    // changing the time always starts over, predictably.
    function setDuration(seconds: int): void {
        countdown.stop();
        const clamped = Math.min(root.maxSeconds, Math.max(root.minSeconds, seconds));
        root.totalSeconds = clamped;
        root.remainingSeconds = clamped;
        root.isRunning = false;
        root.isFinished = false;
        root.saveState();
    }

    // Convert dial angle (0..360) → minutes (snap per minute, 0 = 60).
    function setFromAngle(angleDeg: real): void {
        let mins = Math.round(angleDeg / 6);
        if (mins <= 0)
            mins = 60;
        mins = Math.min(60, Math.max(1, mins));
        root.setDuration(mins * 60);
    }

    function start(): void {
        if (root.remainingSeconds <= 0)
            root.remainingSeconds = root.totalSeconds;
        root.isFinished = false;
        root.isRunning = true;
        countdown.start();
        root.saveState();
    }

    function pause(): void {
        root.isRunning = false;
        countdown.stop();
        root.saveState();
    }

    function reset(): void {
        countdown.stop();
        root.remainingSeconds = root.totalSeconds;
        root.isRunning = false;
        root.isFinished = false;
        root.saveState();
    }

    // Requires the `libnotify` package (Arch: `sudo pacman -S libnotify`).
    // Sent through notify-send so Caelestia's own NotificationDaemon
    // renders it as a native popup.
    function notifyDone(): void {
        Quickshell.execDetached([
            "notify-send", "-a", "caelestia-shell",
            "-u", "critical",
            "Timer done",
            "Time is up — take a break"
        ]);
    }

    FileView {
        id: store
        path: Paths.home + "/.config/quickshell/caelestia/timer.json"
        printErrors: false
        watchChanges: false
        blockLoading: true
        onLoadedChanged: loadState()
    }

    // Guard so the two load triggers (onLoadedChanged + onCompleted) run once.
    property bool stateLoaded: false

    function saveState(): void {
        // endTime lets a fresh instance compute remaining time from the clock,
        // no per-second disk writes needed while running.
        const endTime = root.isRunning ? Date.now() + root.remainingSeconds * 1000 : 0;
        try {
            store.setText(JSON.stringify({
                total: root.totalSeconds,
                remaining: root.remainingSeconds,
                running: root.isRunning,
                endTime: endTime
            }));
        } catch (e) {
            console.warn("[TimerService] failed to save:", e);
        }
    }

    function loadState(): void {
        if (root.stateLoaded)
            return;
        root.stateLoaded = true;
        let raw = "";
        try {
            raw = store.text();
        } catch (e) {
            raw = "";
        }
        if (!raw || !raw.trim())
            return;
        try {
            const s = JSON.parse(raw);
            if (typeof s.total === "number")
                root.totalSeconds = Math.min(root.maxSeconds, Math.max(root.minSeconds, s.total));
            if (typeof s.remaining === "number")
                root.remainingSeconds = Math.max(0, Math.min(root.totalSeconds, s.remaining));
            if (s.running === true && typeof s.endTime === "number") {
                const left = Math.ceil((s.endTime - Date.now()) / 1000);
                if (left > 0) {
                    // Still time left — resume where the wall clock says we are.
                    root.remainingSeconds = Math.min(root.totalSeconds, left);
                    root.isFinished = false;
                    root.isRunning = true;
                    countdown.start();
                } else {
                    // Expired while away. Notify only if it just happened —
                    // a stale timer.json (e.g. shell killed mid-run days ago)
                    // must not pop a phantom notification on fresh start.
                    // saveState() in both branches so a later restart does
                    // not report the same expiry twice.
                    const overdue = Date.now() - s.endTime;
                    root.remainingSeconds = 0;
                    root.isRunning = false;
                    root.isFinished = true;
                    root.saveState();
                    if (overdue < 5 * 60 * 1000)
                        root.notifyDone();
                }
            }
        } catch (e) {
            console.warn("[TimerService] timer.json corrupt, using defaults:", e);
        }
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
                root.saveState();
            }
        }
    }

    Component.onCompleted: loadState()
}
