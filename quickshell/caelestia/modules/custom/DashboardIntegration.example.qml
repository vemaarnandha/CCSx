// DashboardIntegration.example.qml — EXAMPLE, do not load directly.
// Copy one of the options below into your Caelestia dashboard files.
//
// OPTION A (recommended, currently live): New tab in modules/dashboard/Content.qml
// ─────────────────────────────────────────────────────────────────────
// 1. Import at the top of Content.qml (sibling-dir import, same pattern as
//    built-ins like `import "dash"`):
//    import "../custom"
//
// 2. Add an entry to `dashboardTabs` (alongside Dashboard/Media/Performance):
//
//    {
//        component: focusComponent,
//        iconName: "timer",
//        text: Tr.tr("Focus"),
//        enabled: true
//    }
//
// 3. Define the component (alongside dashComponent/mediaComponent):
//
//    Component {
//        id: focusComponent
//        RowLayout {
//            spacing: Tokens.spacing.medium
//            TimerWidget { Layout.alignment: Qt.AlignTop }
//            TodoWidget { Layout.alignment: Qt.AlignTop }
//        }
//    }
//
//
// OPTION B: Embed directly into the Dashboard tab (modules/dashboard/dash/Dash.qml)
// ─────────────────────────────────────────────────────────────────────
//    RowLayout {
//        Layout.fillWidth: true
//        spacing: Tokens.spacing.medium
//        TimerWidget { Layout.fillWidth: true }
//        TodoWidget { Layout.fillWidth: true }
//    }
//
//
// OPTION C: Standalone test without Caelestia (quick debug)
// ─────────────────────────────────────────────────────────────────────
//    Run: qs -p /path/to/TimerWidget.qml
//    For TodoWidget (needs Paths.home), mock it first or load inside the full shell.
