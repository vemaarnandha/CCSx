// EventService.qml — app-lifetime calendar event store (single source of truth).
//
// The singleton owns the event list so state outlives the dashboard Loader
// (Loaders destroy widgets on close). Views are pure projections keyed by
// date string — every mutation reassigns root.list and writes events.json
// immediately, so data can never duplicate or desync. Schema:
// { "id": string, "date": "YYYY-MM-DD", "title": string,
//   "time": "HH:MM" or "", "done": bool }.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    // Events: array of { id, date, title, time, done }. Never mutated in
    // place — always reassigned so bindings update. Guard first-frame reads
    // with (list ?? []) until the singleton is ready.
    property var list: []

    function persist(): void {
        try {
            store.setText(JSON.stringify(root.list));
        } catch (e) {
            console.warn("[EventService] failed to save:", e);
        }
    }

    // Zero-padded "YYYY-MM-DD" key. Month is 1-based (January = 1).
    function dateKey(y: int, m: int, d: int): string {
        const mm = m < 10 ? "0" + m : "" + m;
        const dd = d < 10 ? "0" + d : "" + d;
        return y + "-" + mm + "-" + dd;
    }

    function todayKey(): string {
        const now = new Date();
        return dateKey(now.getFullYear(), now.getMonth() + 1, now.getDate());
    }

    function eventsOn(dateStr: string): var {
        return (root.list ?? []).filter(ev => ev.date === dateStr);
    }

    function hasEvent(dateStr: string): bool {
        return (root.list ?? []).some(ev => ev.date === dateStr);
    }

    function countOn(dateStr: string): int {
        return (root.list ?? []).filter(ev => ev.date === dateStr).length;
    }

    function addEvent(dateStr: string, title: string, time: string): void {
        const t = (title ?? "").trim();
        // Service stays permissive about dates (view layer disables past
        // Add); only an empty title is rejected.
        if (t.length === 0)
            return;
        const id = Date.now().toString(36) + Math.floor(Math.random() * 1679616).toString(36);
        const next = (root.list ?? []).slice(0);
        next.push({ id: id, date: dateStr, title: t, time: time ?? "", done: false });
        root.list = next;
        root.persist();
    }

    function toggleDone(id: string): void {
        const cur = (root.list ?? []).slice(0);
        const i = cur.findIndex(ev => ev && ev.id === id);
        if (i < 0)
            return;
        cur[i] = { id: cur[i].id, date: cur[i].date, title: cur[i].title, time: cur[i].time, done: !cur[i].done };
        root.list = cur;
        root.persist();
    }

    function deleteEvent(id: string): void {
        const next = (root.list ?? []).filter(ev => !(ev && ev.id === id));
        if (next.length === (root.list ?? []).length)
            return;
        root.list = next;
        root.persist();
    }

    function refresh(): void {
        store.reload();
    }

    FileView {
        id: store
        path: Paths.home + "/.config/quickshell/caelestia/events.json"
        printErrors: false
        watchChanges: false
        onLoaded: {
            let arr = [];
            try {
                const parsed = JSON.parse(text());
                if (Array.isArray(parsed))
                    arr = parsed;
            } catch (e) {
                console.warn("[EventService] events.json corrupt, starting empty:", e);
            }
            // Normalize + dedupe: drop entries without a valid date/title,
            // collapse duplicate ids to the first occurrence, so a damaged
            // file heals itself on first load.
            const dateRe = /^\d{4}-\d{2}-\d{2}$/;
            const seen = {};
            const clean = [];
            for (let i = 0; i < arr.length; i++) {
                const it = arr[i];
                if (!it || typeof it.date !== "string" || !dateRe.test(it.date))
                    continue;
                if (typeof it.title !== "string" || it.title.trim().length === 0)
                    continue;
                const eid = typeof it.id === "string" && it.id.length > 0 ? it.id : null;
                if (!eid || seen[eid])
                    continue;
                seen[eid] = true;
                clean.push({
                    id: eid,
                    date: it.date,
                    title: it.title,
                    time: typeof it.time === "string" ? it.time : "",
                    done: !!it.done
                });
            }
            if (clean.length !== arr.length)
                console.warn("[EventService] normalized events on load: kept " + clean.length + " of " + arr.length);
            root.list = clean;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                Qt.callLater(() => setText("[]"));
        }
    }
}
