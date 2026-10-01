#!/usr/bin/env bash
#
# caelestia-shell-customX installer.
#
# What it does:
#   1. Checks required commands (warns, does not install).
#   2. Backs up any existing ~/.config/quickshell (timestamped, keeps 3).
#   3. Creates the user shadow copy of the system caelestia shell
#      (/etc/xdg/quickshell/caelestia -> ~/.config/quickshell/caelestia)
#      so upstream updates never overwrite your widgets.
#   4. Overlays this project's files (see FILES below).
#   5. Applies idempotent source patches (see apply_patches).
#   6. Reloads the shell.
#
# Data-driven: when adding a feature, only extend FILES / SEEDS / PATCHES.
# Run safely first with:  DRY_RUN=1 ./install.sh
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/quickshell/caelestia"
DEST="$HOME/.config/quickshell/caelestia"
SYSTEM_SRC="/etc/xdg/quickshell/caelestia"
BACKUP_ROOT="$HOME/.config/quickshell-backups"
DRY_RUN="${DRY_RUN:-0}"

# ── Data: edit here when adding features ─────────────────────────────
# Project files overlaid onto the user shadow, relative to SRC/DEST.
FILES=(
    "modules/custom/EventService.qml"
    "modules/custom/EventPopover.qml"
    "modules/custom/CalendarPatch.example.qml"
    "modules/custom/TimerService.qml"
    "modules/custom/TimerWidget.qml"
    "modules/custom/TodoService.qml"
    "modules/custom/TodoTaskList.qml"
    "modules/custom/TodoWidget.qml"
    "modules/custom/DashboardIntegration.example.qml"
    "modules/custom/qmldir"
    "modules/background/DesktopClock.qml"
)
# Seed data: copied ONLY when the target does not exist (never overwrite).
# Empty by design: TimerService/TodoService/EventService auto-create their
# state files (timer.json/todos.json/events.json) on first save, so no
# seeds are required.
SEEDS=(
)
# Required commands (checked, never auto-installed).
REQUIRED_CMDS=(qs caelestia notify-send paplay python3)
# ─────────────────────────────────────────────────────────────────────

log()  { printf '[install] %s\n' "$*"; }
dry()  { if [ "$DRY_RUN" = "1" ]; then printf '[dry-run] %s\n' "$*"; return 0; fi; return 1; }
run()  { if dry "$*"; then return 0; fi; "$@"; }

fail() { printf '[install] ERROR: %s\n' "$*" >&2; exit 1; }

font_present() {
    [ -n "$(fc-list 2>/dev/null | grep -i 'material symbols' || true)" ]
}

check_deps() {
    local missing=0
    for cmd in "${REQUIRED_CMDS[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            printf '[install] WARN: command not found: %s\n' "$cmd"
            missing=1
        fi
    done
    if ! font_present; then
        printf '[install] WARN: Material Symbols font not detected (icons may show as boxes)\n'
    fi
    if [ -z "$(fc-list 2>/dev/null | grep -i 'lincoln electric' || true)" ]; then
        printf '[install] WARN: Lincoln Electric font not detected (desktop clock falls back to system font)\n'
    fi
    if [ "$missing" = "1" ]; then
        printf '[install] Install the missing tools for your distro, then re-run.\n'
        printf '[install] Arch example: sudo pacman -S quickshell caelestia-shell libnotify pipewire\n'
    fi
    [ -d "$SYSTEM_SRC" ] || fail "system shell not found at $SYSTEM_SRC (install caelestia-shell first)"
}

backup_existing() {
    if [ ! -d "$HOME/.config/quickshell" ]; then
        return 0
    fi
    local stamp; stamp="$(date +%Y%m%d-%H%M%S)"
    log "backing up ~/.config/quickshell -> $BACKUP_ROOT/$stamp"
    run mkdir -p "$BACKUP_ROOT"
    run cp -r "$HOME/.config/quickshell" "$BACKUP_ROOT/$stamp"
    # Keep only the 3 newest backups.
    if [ "$DRY_RUN" != "1" ]; then
        ls -1 "$BACKUP_ROOT" | sort | head -n -3 | while read -r old; do
            [ -n "$old" ] && rm -rf "$BACKUP_ROOT/$old"
        done
    fi
}

ensure_shadow() {
    if [ -f "$DEST/shell.qml" ]; then
        log "user shadow already exists, keeping it"
        return 0
    fi
    log "creating user shadow: $SYSTEM_SRC -> $DEST"
    run mkdir -p "$(dirname "$DEST")"
    run cp -r "$SYSTEM_SRC" "$DEST"
}

overlay_files() {
    local rel
    for rel in "${FILES[@]}"; do
        [ -f "$SRC/$rel" ] || fail "repo file missing: quickshell/caelestia/$rel"
        # Upstream-overwrite files: preserve the pristine copy BEFORE
        # overlaying, so uninstall.sh can restore it. (apply_patches runs
        # after overlay, too late for these.)
        if [ "$rel" = "modules/background/DesktopClock.qml" ] && [ ! -f "$DEST/$rel.bak" ] && [ -f "$DEST/$rel" ]; then
            log "backup pristine $rel -> $rel.bak"
            run cp "$DEST/$rel" "$DEST/$rel.bak"
        fi
        log "install $rel"
        run mkdir -p "$(dirname "$DEST/$rel")"
        run cp "$SRC/$rel" "$DEST/$rel"
    done
    for rel in "${SEEDS[@]}"; do
        if [ -f "$DEST/$rel" ]; then
            log "seed $rel already exists, keeping user data"
        else
            log "seed $rel (new file)"
            run cp "$SRC/$rel" "$DEST/$rel"
        fi
    done
}

apply_patches() {
    log "applying source patches (idempotent)"
    # Keep pristine copies once, so uninstall.sh can restore them.
    for f in "modules/dashboard/Content.qml" "modules/drawers/ContentWindow.qml" "modules/dashboard/dash/Calendar.qml" "modules/background/DesktopClock.qml"; do
        if [ ! -f "$DEST/$f.bak" ]; then
            run cp "$DEST/$f" "$DEST/$f.bak"
        fi
    done
    if dry "python3 patch Content.qml + ContentWindow.qml + Calendar.qml"; then
        return 0
    fi
    python3 - "$DEST" <<'PYEOF'
import sys

dest = sys.argv[1]

def patch(path, marker, old, new):
    with open(path) as f:
        text = f.read()
    if marker in text:
        print(f"  already applied: {marker}")
        return
    if old not in text:
        print(f"  WARN: anchor not found in {path}, skipping patch: {marker}")
        return
    with open(path, "w") as f:
        f.write(text.replace(old, new, 1))
    print(f"  applied: {marker}")

# --- Patch 1: Focus tab import -------------------------------------
content = dest + "/modules/dashboard/Content.qml"
patch(content,
      'import "../custom"',
      'import qs.components.filedialog\n',
      'import qs.components.filedialog\nimport "../custom"\n')

# --- Patch 2: Focus tab entry (after the weather entry) ------------
patch(content,
      'component: focusComponent',
      '''            {
                component: weatherComponent,
                iconName: "cloud",
                text: Tr.tr("Weather"),
                enabled: Config.dashboard.showWeather
            }
''',
      '''            {
                component: weatherComponent,
                iconName: "cloud",
                text: Tr.tr("Weather"),
                enabled: Config.dashboard.showWeather
            },
            {
                component: focusComponent,
                iconName: "timer",
                text: Tr.tr("Focus"),
                enabled: true
            }
''')

# --- Patch 3: Focus tab component (after weatherComponent block) ---
patch(content,
      'id: focusComponent',
      '''            Component {
                id: weatherComponent

                WeatherTab {}
            }
''',
      '''            Component {
                id: weatherComponent

                WeatherTab {}
            }

            Component {
                id: focusComponent

                RowLayout {
                    spacing: Tokens.spacing.small

                    TimerWidget {
                        Layout.alignment: Qt.AlignTop
                    }
                    TodoWidget {
                        Layout.alignment: Qt.AlignTop
                    }
                }
            }
''')

# --- Patch 4: dashboard keyboard focus (text input in widgets) -----
window = dest + "/modules/drawers/ContentWindow.qml"
patch(window,
      'screenState.dashboard || screenState.launcher',
      'WlrLayershell.keyboardFocus: screenState.launcher || screenState.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None',
      'WlrLayershell.keyboardFocus: screenState.dashboard || screenState.launcher || screenState.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None')

# --- Patch 5: Calendar events import ---------------------------------
calendar = dest + "/modules/dashboard/dash/Calendar.qml"
patch(calendar,
      'qs.modules.custom',
      'import qs.services\n',
      'import qs.services\nimport qs.modules.custom\n')

# --- Patch 5b: Calendar selected date state ---------------------------
patch(calendar,
      'property string selectedKey',
      '''    property date currentDate: screenState.dashboardDate
''',
      '''    property date currentDate: screenState.dashboardDate
    property string selectedKey: ""
''')

# --- Patch 5c: close popover on month change ---------------------------
patch(calendar,
      'onCurrentDateChanged',
      '''    property string selectedKey: ""
''',
      '''    property string selectedKey: ""
    onCurrentDateChanged: root.selectedKey = ""
''')

# --- Patch 6: Calendar event dot + click + popover -------------------
# Contract with modules/custom: EventService.hasEvent(key)/countOn(key)
# take "YYYY-MM-DD", EventPopover { dateKey/show/onClose }.
# Matches CalendarPatch.example.qml + EventPopover.qml APIs.
patch(calendar,
      'EventService.hasEvent',
      '''                delegate: Item {
                    id: dayItem

                    required property var model

                    implicitWidth: implicitHeight
                    implicitHeight: text.implicitHeight + Tokens.padding.small
''',
      '''                delegate: Item {
                    id: dayItem

                    required property var model
                    readonly property string dateKey: Qt.formatDate(dayItem.model.date, "yyyy-MM-dd")

                    implicitWidth: implicitHeight
                    implicitHeight: text.implicitHeight + Tokens.padding.small + 7
''')

patch(calendar,
      'eventDot',
      '''                        opacity: dayItem.model.today || dayItem.model.month === grid.month ? 1 : 0.4
                        font: Tokens.font.body.small
                    }
                }
            }
''',
      '''                        opacity: dayItem.model.today || dayItem.model.month === grid.month ? 1 : 0.4
                        font: Tokens.font.body.small
                    }

                    Rectangle {
                        id: eventDot
                        anchors.top: text.bottom
                        anchors.topMargin: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 5
                        height: 5
                        radius: width / 2
                        color: Colours.palette.m3primary
                        visible: EventService.hasEvent(dayItem.dateKey)
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedKey = dayItem.dateKey
                    }
                }
            }
''')

patch(calendar,
      'id: eventPopover',
      '''                    source: grid
                    sourceColor: Colours.palette.m3onSurface
                    colorizationColor: Colours.palette.m3onPrimary
                }
            }
        }
    }
}''',
      '''                    source: grid
                    sourceColor: Colours.palette.m3onSurface
                    colorizationColor: Colours.palette.m3onPrimary
                }
            }
        }
    }

    EventPopover {
        id: eventPopover
        anchors.fill: parent
        dateKey: root.selectedKey
        show: root.selectedKey !== ""
        onClose: root.selectedKey = ""
    }
}''')

# --- Patch 6b: RETIRED (frosted backdrop removed) ----------------------
# The live-blur experiment proved ineffective on this GPU, so the dialog
# uses a flat surface and no longer needs a capture source. This block
# removes the line from shadows patched while 6b was active; no-ops
# everywhere else. Kept (not deleted) so old shadows heal on reinstall.
retired = dest + "/modules/dashboard/dash/Calendar.qml"
with open(retired) as f:
    caltext = f.read()
if '        blurSource: inner\n' in caltext:
    with open(retired, "w") as f:
        f.write(caltext.replace('        blurSource: inner\n', '', 1))
    print("  retired: blurSource: inner")
else:
    print("  already retired: blurSource: inner")
PYEOF
}

verify() {
    log "verifying"
    local ok=1
    local rel
    for rel in "${FILES[@]}"; do
        cmp -s "$SRC/$rel" "$DEST/$rel" || { printf '[install] MISMATCH: %s\n' "$rel"; ok=0; }
    done
    grep -q 'component: focusComponent' "$DEST/modules/dashboard/Content.qml" || { echo "[install] MISMATCH: Focus tab entry"; ok=0; }
    grep -q 'screenState.dashboard || screenState.launcher' "$DEST/modules/drawers/ContentWindow.qml" || { echo "[install] MISMATCH: keyboard focus patch"; ok=0; }
    grep -q 'id: eventPopover' "$DEST/modules/dashboard/dash/Calendar.qml" || { echo "[install] MISMATCH: calendar events patch"; ok=0; }
    [ "$ok" = "1" ] && log "all files verified OK" || fail "verification failed"
}

main() {
    log "caelestia-shell-customX installer (DRY_RUN=$DRY_RUN)"
    check_deps
    backup_existing
    ensure_shadow
    overlay_files
    apply_patches
    if [ "$DRY_RUN" != "1" ]; then
        verify
        log "reloading shell"
        caelestia shell -r || printf '[install] WARN: reload failed, run: caelestia shell -r\n'
        log "done — open the dashboard and check the Focus tab"
    else
        log "dry run complete, nothing was changed"
    fi
}

main "$@"
