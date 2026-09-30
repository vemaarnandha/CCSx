// CalendarPatch.example.qml — EXAMPLE patch spec, do not load directly.
//
// Shows how upstream
//   /etc/xdg/quickshell/caelestia/modules/dashboard/dash/Calendar.qml (259 lines)
// gains an event dot + click opening the EventPopover. Apply with the
// installer (idempotent python patch) or by hand. Upstream wheel/month nav,
// middle-click today reset, and animations stay untouched.
//
// Wiring summary: root.selectedKey holds the open date ("YYYY-MM-DD", empty
// = closed). Each day delegate computes its own key via Qt.formatDate and
// opens the popover on left-click. The popover instance overlays the whole
// Calendar (anchors.fill parent + scrim) so the tight Dash.qml grid never
// expands. Event state lives in the EventService singleton (Loader-safe).


// ── (a) Import ─────────────────────────────────────────────────────
// Anchor (upstream lines 1-11):
//   import qs.components.controls
//   import qs.components.effects
//   import qs.services
//
// OLD:
//   import qs.services
//
// NEW (append one line after `import qs.services`):
//   import qs.services
//   import qs.modules.custom


// ── (b) Selection state on root ────────────────────────────────────
// Anchor (upstream lines 13-22):
//   CustomMouseArea {
//       id: root
//       required property ScreenState screenState
//       property date currentDate: screenState.dashboardDate
//
// OLD:
//       property date currentDate: screenState.dashboardDate
//
// NEW (insert directly below that line):
//       property date currentDate: screenState.dashboardDate
//       property string selectedKey: ""


// ── (c) Day delegate: dot + click ──────────────────────────────────
// Anchors (upstream lines 195-220):
//   delegate: Item {
//       id: dayItem
//       required property var model
//       implicitWidth: implicitHeight
//       implicitHeight: text.implicitHeight + Tokens.padding.small
//       StyledText {
//           id: text
//           ...
//           text: grid.locale.toString(dayItem.model.day)
//           ...
//       }
//   }
//
// The delegate model exposes .date (JS Date), .day, .today, .month.
// Qt.formatDate(model.date, "yyyy-MM-dd") yields the EventService key;
// zero-padded, so lexical compare orders chronologically.
//
// OLD (whole delegate body):
//   delegate: Item {
//       id: dayItem
//
//       required property var model
//
//       implicitWidth: implicitHeight
//       implicitHeight: text.implicitHeight + Tokens.padding.small
//
//       StyledText {
//           id: text
//
//           anchors.centerIn: parent
//
//           horizontalAlignment: Text.AlignHCenter
//           text: grid.locale.toString(dayItem.model.day)
//           ...
//       }
//   }
//
// NEW (keep everything, add key + dot + click; cell height grows by 7px only):
//   delegate: Item {
//       id: dayItem
//
//       required property var model
//       readonly property string dateKey: Qt.formatDate(dayItem.model.date, "yyyy-MM-dd")
//       // Guarded: hasEvent() reads (list ?? []) so first frames are safe.
//
//       implicitWidth: implicitHeight
//       implicitHeight: text.implicitHeight + Tokens.padding.small + 7
//
//       StyledText {
//           id: text
//           // ... unchanged (anchors.centerIn, day number, weekend colors,
//           // opacity for out-of-month days, Tokens.font.body.small) ...
//       }
//
//       // 5px event dot under the number. M3 primary only, no new colors.
//       Rectangle {
//           anchors.top: text.bottom
//           anchors.topMargin: 1
//           anchors.horizontalCenter: parent.horizontalCenter
//           width: 5
//           height: 5
//           radius: width / 2
//           color: Colours.palette.m3primary
//           visible: EventService.hasEvent(dayItem.dateKey)
//       }
//
//       // Left-click opens the popover. Middle-click still hits the root
//       // CustomMouseArea (today reset) — this MouseArea only takes Left.
//       MouseArea {
//           anchors.fill: parent
//           acceptedButtons: Qt.LeftButton
//           cursorShape: Qt.PointingHandCursor
//           onClicked: root.selectedKey = dayItem.dateKey
//       }
//   }
//
// Optional count badge variant (same anchor, replaces the dot Rectangle):
//   StyledText {
//       anchors.top: text.bottom
//       anchors.horizontalCenter: parent.horizontalCenter
//       visible: EventService.hasEvent(dayItem.dateKey)
//       text: EventService.countOn(dayItem.dateKey) > 1 ? "•".repeat(Math.min(EventService.countOn(dayItem.dateKey), 3)) : "•"
//       color: Colours.palette.m3primary
//       font.pixelSize: 8
//   }


// ── (d) Popover instance (overlay, not layout) ─────────────────────
// Anchor (upstream lines 89-90 + 257-259):
//   ColumnLayout {
//       id: inner
//       ...
//   }           <- end of `inner`
// }             <- end of root CustomMouseArea
//
// OLD (tail of file):
//           }
//       }
//   }
//
// NEW: insert the popover as a direct child of root, AFTER `inner` closes
// but BEFORE root closes, so anchors.fill covers the whole Calendar:
//
//           }
//       }
//
//       EventPopover {
//           anchors.fill: parent
//           dateKey: root.selectedKey
//           show: root.selectedKey !== ""
//           onClose: root.selectedKey = ""
//       }
//   }
//
// Why here: Dash.qml places Calendar in a tight GridLayout cell
// (row1 col1-span3); an overlay keeps implicitHeight stable while the
// scrim still catches outside clicks. Esc is handled inside EventPopover
// (Keys.onPressed) — no extra wiring needed.


// ── Untouched (do NOT patch) ───────────────────────────────────────
// - onWheel month nav (lines 28-33) and chevron buttons (108, 155).
// - Middle-click today reset (lines 39-40) + month-title StateLayer reset.
// - currentDate Behavior animation + trOutAnim (lines 52-87).
// - todayIndicator MaterialShape Sunny + Colouriser (lines 223-256).
// - DayOfWeekRow delegate (lines 165-172).
