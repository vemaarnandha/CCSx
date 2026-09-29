# Changelog

## [0.1.1] - 2026-09-30

### Fixed
- Tasks card: add dialog actually adds tasks (missing dialog id broke
  both the Add button and Enter).
- Tasks card: no more `map`/`length` of undefined warnings on first
  frames before the service loads.
- TodoService: non-blocking async load with missing-file creation, so
  the singleton always resolves with its functions available.
- Ship `modules/custom/qmldir` declaring both services as singletons
  (the engine's generated listing missed TodoService, breaking all
  service calls) + install/uninstall overlay entries.
- Timer card: remove redundant cycle badge (session dots + `x of 4`
  already show the cycle).

## [0.1.0] - 2026-09-29

First public snapshot.

### Added
- Focus dashboard tab (Timer + Tasks side by side).
- Timer card: Focus/Short/Long modes, 4-session cycle with dots,
  urgency ramp, ±min adjust, Start/Pause/Resume + Reset, completion chime
  with persisted mute toggle, Stopwatch tab with laps, cycle badge.
- Tasks card: Unfinished/Done tabs, FAB + add dialog, check/delete,
  Clear completed, JSON persistence with self-healing load.
- TimerService / TodoService app-lifetime singletons (countdown + notify
  with dashboard closed, wall-clock resume after restart).
- Data-driven `install.sh` (backup, shadow copy, overlay, idempotent
  patches, verify, reload) + `uninstall.sh` (+ `--purge-data`).
- README, GPL-3.0 LICENSE, CHANGELOG.

### Compatibility
- Tested against the caelestia-shell `/etc/xdg` snapshot present on
  2026-09-29 (Content.qml with Dashboard/Media/Performance/Weather tabs).
