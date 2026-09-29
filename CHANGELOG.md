# Changelog

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
