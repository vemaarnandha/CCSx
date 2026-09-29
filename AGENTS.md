# AGENTS.md — caelestia-shell-customX

Custom widgets (Pomodoro timer + todo list) overlaying the upstream
Caelestia Shell (Quickshell/Hyprland) via a user shadow copy.

## Project map

- `quickshell/caelestia/` — overlay source (edit here, never directly
  in the live config).
- `~/.config/quickshell/caelestia/` — user shadow copy, this is what
  actually runs. Created once from `/etc/xdg/quickshell/caelestia`
  (upstream); upstream updates never touch it.
- `~/.config/quickshell/caelestia/modules/custom/` — our widgets +
  services. Shell log: `/run/user/1000/quickshell/by-id/*/log.qslog`.
- Editing the repo changes nothing live until `./install.sh` copies
  files over + reloads the shell.

## Installer (data-driven, keep it that way)

- `install.sh`: backup → ensure shadow → overlay `FILES` → idempotent
  python patches → `cmp`/`grep` verify → `caelestia shell -r`.
- Adding/renaming/removing a feature = extend `FILES`/`SEEDS`/patches
  only. Mirror every `FILES` change in `uninstall.sh`.
- `todos.json`/`timer.json` are runtime data, never seeds — the
  services self-heal on load.
- `caelestia shell -r` runs FOREGROUND attached to its terminal
  (closing the terminal kills the shell). For installs use:
  `./install.sh </dev/null >~/install.log 2>&1 & disown`

## QML gotchas (learned the hard way)

1. **Singletons need `modules/custom/qmldir`.** Every file with
   `pragma Singleton` in `modules/custom/` MUST be declared there
   (`singleton Name 1.0 Name.qml`). The engine auto-generates a
   listing when none exists and it once missed TodoService (while
   catching TimerService) — the service then resolved as a plain
   component: `.list` undefined, methods "not a function". Never
   trust auto-detection; the explicit qmldir wins.
2. **Guard first-frame bindings.** Properties reading a singleton
   MUST use `(X ?? [])`, e.g. `(TodoService.list ?? []).map(...)`,
   `(root.taskList ?? []).length`. On first frames the singleton
   isn't ready → `map`/`length` of undefined WARN spam.
3. **Services load async.** No `blockLoading: true`, no manual
   `reload()` in `Component.onCompleted` (FileView auto-loads).
   Handle missing files with `onLoadFailed` + `FileViewError`.
4. **No `qmllint`.** It can't resolve Caelestia plugin types.
   Validation = `DRY_RUN=1 ./install.sh` (expect `verified OK`) +
   reload + grep the newest `log.qslog` for `TypeError` (expect 0).
5. **Dashboard Loaders destroy widgets on close** (hence
   `Singleton` services for app-lifetime state) and cause benign
   `destroyed during incubation` INFO + one pre-existing `active`
   binding-loop WARN in `Content.qml` — not errors.

## Definition of Done (every widget change)

1. `install.sh` FILES + `uninstall.sh` FILES in sync with the tree.
2. `DRY_RUN=1 ./install.sh` → `verified OK`.
3. `README.md` Features/Usage claims match reality (no stale
   feature mentions).
4. `CHANGELOG.md`: entry under Unreleased (same style as 0.1.0).
5. UI changed → screenshot in `docs/screenshots/` must be refreshed.
   Agents cannot screenshot the live shell — ask the user to retake
   from their running shell and hand over the file.
6. Real install + reload, new log has 0 `TypeError`.

## Git

- Atomic commits, one logical unit each (service vs view layers
  split; release-notes/README docs may ride together).
- Messages: PLAIN English, imperative, repo style (`git log` —
  e.g. "Add ...", "Fix ...", "Remove ..."). No `feat:` prefixes.
- Never push without being asked. Never rewrite pushed history
  (local-only amends are fine while unpushed).

## Language

- User speaks Indonesian — answer in Indonesian. Docs/comments/
  UI strings stay in English.
