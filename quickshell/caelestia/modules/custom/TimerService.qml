// TimerService.qml — app-lifetime pomodoro engine behind the Focus tab timer.
//
// Singleton: it outlives the dashboard Loader (which destroys widgets every
// time the dashboard closes), so the countdown keeps ticking and its
// notification fires exactly on time even with the dashboard closed.
// Limit: the shell process itself must be running — nothing can notify
// after logout / shell kill. State persists in timer.json and resumes
// from wall-clock time after a full shell restart.
//
// Pomodoro model: focus sessions advance sessionsCompleted; every 4th focus
// is followed by a long break, otherwise a short break. Breaks lead back
// to focus. All durations (minutes) live here so any view stays consistent.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    // ── Mode & session state ──
    // mode: "focus" | "short" | "long"
    property string mode: "focus"
    property int focusMinutes: 25
    property int shortMinutes: 5
    property int longMinutes: 15
    property int sessionsCompleted: 0
    readonly property int cycleLength: 4
    readonly property int cycleDone: sessionsCompleted % cycleLength

    property int totalSeconds: 25 * 60
    property int remainingSeconds: 25 * 60
    property bool isRunning: false
    property bool isFinished: false
    property bool soundEnabled: true

    function toggleSound(): void {
        root.soundEnabled = !root.soundEnabled;
        root.saveState();
    }

    readonly property int minSeconds: 10
    readonly property int maxSeconds: 60 * 60

    // Ratio 0..1 for the progress ring.
    readonly property real progress: totalSeconds > 0 ? remainingSeconds / totalSeconds : 0

    // Urgency ramp for the ring color (resolved to theme colors by the view):
    // 0 = normal, 1 = low (<25% left), 2 = critical (<10% left or done).
    readonly property int urgency: {
        if (root.isFinished)
            return 2;
        const frac = root.totalSeconds > 0 ? root.remainingSeconds / root.totalSeconds : 1;
        if (frac <= 0.1)
            return 2;
        if (frac <= 0.25)
            return 1;
        return 0;
    }

    // Format MM:SS, e.g. 1500 → "25:00"
    function fmt(s: int): string {
        const m = Math.floor(Math.max(0, s) / 60);
        const sec = Math.max(0, s) % 60;
        return (m < 10 ? "0" + m : "" + m) + ":" + (sec < 10 ? "0" + sec : "" + sec);
    }

    function modeDuration(m: string): int {
        if (m === "short")
            return root.shortMinutes * 60;
        if (m === "long")
            return root.longMinutes * 60;
        return root.focusMinutes * 60;
    }

    function setMode(m: string): void {
        root.mode = m;
        root.setDuration(root.modeDuration(m));
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

    // Nudge the current total without switching mode (custom adjust chips).
    function adjustSeconds(delta: int): void {
        root.setDuration(root.totalSeconds + delta);
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

    // Advance the pomodoro cycle when a session ends. silent=true skips the
    // notification (stale on-disk state), but still advances + saves.
    function finishSession(silent: bool): void {
        countdown.stop();
        root.isRunning = false;
        if (root.mode === "focus") {
            root.sessionsCompleted += 1;
            const longBreak = root.sessionsCompleted % root.cycleLength === 0;
            root.mode = longBreak ? "long" : "short";
            root.totalSeconds = root.remainingSeconds = root.modeDuration(root.mode);
            root.isFinished = true;
            if (!silent)
                root.notifyDone("Focus session done", longBreak ? "4 sessions — take a long break" : "Take a short break");
        } else {
            root.mode = "focus";
            root.totalSeconds = root.remainingSeconds = root.modeDuration("focus");
            root.isFinished = true;
            if (!silent)
                root.notifyDone("Break over", "Back to focus");
        }
        root.saveState();
    }

    // Requires the `libnotify` package (Arch: `sudo pacman -S libnotify`)
    // for the popup and a PipeWire/PulseAudio player (`paplay`) for the alarm.
    // Sent through notify-send so Caelestia's own NotificationDaemon
    // renders it as a native popup.
    function notifyDone(title: string, body: string): void {
        Quickshell.execDetached([
            "notify-send", "-a", "caelestia-shell",
            "-u", "critical",
            title, body
        ]);
        if (root.soundEnabled)
            Quickshell.execDetached([
                "paplay",
                "/usr/share/sounds/freedesktop/stereo/complete.oga"
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
                endTime: endTime,
                mode: root.mode,
                sessionsCompleted: root.sessionsCompleted,
                soundEnabled: root.soundEnabled,
                focusMinutes: root.focusMinutes,
                shortMinutes: root.shortMinutes,
                longMinutes: root.longMinutes
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
            if (typeof s.focusMinutes === "number")
                root.focusMinutes = s.focusMinutes;
            if (typeof s.shortMinutes === "number")
                root.shortMinutes = s.shortMinutes;
            if (typeof s.longMinutes === "number")
                root.longMinutes = s.longMinutes;
            if (typeof s.sessionsCompleted === "number")
                root.sessionsCompleted = Math.max(0, s.sessionsCompleted);
            if (typeof s.soundEnabled === "boolean")
                root.soundEnabled = s.soundEnabled;
            if (typeof s.mode === "string" && (s.mode === "focus" || s.mode === "short" || s.mode === "long"))
                root.mode = s.mode;
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
                    // Expired while away. Only report if it just happened —
                    // a stale timer.json must not pop a phantom notification.
                    root.finishSession(Date.now() - s.endTime >= 5 * 60 * 1000);
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
            if (root.remainingSeconds <= 0)
                root.finishSession(false);
        }
    }

    Component.onCompleted: loadState()
}
