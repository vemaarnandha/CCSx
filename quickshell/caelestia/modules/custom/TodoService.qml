// TodoService.qml — app-lifetime todo store (single source of truth).
//
// Adapted from end-4/dots-hyprland services/Todo.qml (GPL-3.0): the service
// owns the list, every mutation writes the file immediately, and views are
// pure projections — so data can never duplicate or desync. Schema stays
// {"text", "done"} to keep existing todos.json files valid.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    // Items: { "text": string, "done": bool }. Never mutated in place —
    // always reassigned so bindings update.
    property var list: []

    function persist(): void {
        try {
            store.setText(JSON.stringify(root.list));
        } catch (e) {
            console.warn("[TodoService] failed to save:", e);
        }
    }

    function addTask(text: string): void {
        const t = text.trim();
        if (t.length === 0)
            return;
        const next = root.list.slice(0);
        next.push({ text: t, done: false });
        root.list = next;
        root.persist();
    }

    function setDone(index: int, done: bool): void {
        if (index < 0 || index >= root.list.length)
            return;
        const next = root.list.slice(0);
        next[index] = { text: next[index].text, done: done };
        root.list = next;
        root.persist();
    }

    function deleteItem(index: int): void {
        if (index < 0 || index >= root.list.length)
            return;
        const next = root.list.slice(0);
        next.splice(index, 1);
        root.list = next;
        root.persist();
    }

    function clearDone(): void {
        root.list = root.list.filter(item => !item.done);
        root.persist();
    }

    function refresh(): void {
        store.reload();
    }

    Component.onCompleted: refresh()

    FileView {
        id: store
        path: Paths.home + "/.config/quickshell/caelestia/todos.json"
        printErrors: false
        watchChanges: false
        blockLoading: true
        onLoaded: {
            let arr = [];
            try {
                const parsed = JSON.parse(store.text());
                if (Array.isArray(parsed))
                    arr = parsed;
            } catch (e) {
                console.warn("[TodoService] todos.json corrupt, starting empty:", e);
            }
            // Normalize + dedupe: identical texts collapse to first occurrence,
            // so a file damaged by older versions heals itself on first load.
            const seen = {};
            const clean = [];
            for (let i = 0; i < arr.length; i++) {
                const it = arr[i];
                if (it && typeof it.text === "string" && !seen[it.text]) {
                    seen[it.text] = true;
                    clean.push({ text: it.text, done: !!it.done });
                }
            }
            root.list = clean;
        }
    }
}
