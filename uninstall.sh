#!/usr/bin/env bash
#
# caelestia-shell-customX uninstaller.
#
# Removes this project's overlay files, restores *.bak files created for
# patched upstream files when present, and optionally restores the newest
# ~/.config/quickshell backup. Never deletes user data (todos.json,
# timer.json) unless --purge-data is passed.
#
set -euo pipefail

DEST="$HOME/.config/quickshell/caelestia"
BACKUP_ROOT="$HOME/.config/quickshell-backups"
DRY_RUN="${DRY_RUN:-0}"
PURGE=0
[ "${1:-}" = "--purge-data" ] && PURGE=1

log() { printf '[uninstall] %s\n' "$*"; }
dry() { if [ "$DRY_RUN" = "1" ]; then printf '[dry-run] %s\n' "$*"; return 0; fi; return 1; }
run() { if dry "$*"; then return 0; fi; "$@"; }

FILES=(
    "modules/custom/TimerService.qml"
    "modules/custom/TimerWidget.qml"
    "modules/custom/TodoService.qml"
    "modules/custom/TodoTaskList.qml"
    "modules/custom/TodoWidget.qml"
    "modules/custom/DashboardIntegration.example.qml"
    "modules/custom/qmldir"
)

log "caelestia-shell-customX uninstaller (DRY_RUN=$DRY_RUN, PURGE=$PURGE)"

for rel in "${FILES[@]}"; do
    if [ -f "$DEST/$rel" ]; then
        log "remove $rel"
        run rm -f "$DEST/$rel"
    fi
done

# Restore patched upstream files from .bak when available.
for bak in "$DEST/modules/dashboard/Content.qml.bak" \
           "$DEST/modules/drawers/ContentWindow.qml.bak"; do
    if [ -f "$bak" ]; then
        log "restore ${bak%.bak}"
        run cp "$bak" "${bak%.bak}"
    fi
done

if [ "$PURGE" = "1" ]; then
    log "purging user data (todos.json, timer.json)"
    run rm -f "$DEST/todos.json" "$DEST/timer.json"
else
    log "keeping user data (pass --purge-data to delete todos.json/timer.json)"
fi

if [ -d "$BACKUP_ROOT" ]; then
    latest="$(ls -1 "$BACKUP_ROOT" 2>/dev/null | sort | tail -n 1)"
    if [ -n "${latest:-}" ]; then
        log "newest backup available: $BACKUP_ROOT/$latest"
        log "to fully restore it: rm -rf ~/.config/quickshell && cp -r $BACKUP_ROOT/$latest ~/.config/quickshell"
    fi
fi

log "done — reload the shell: caelestia shell -r"
