// DashboardIntegration.example.qml — CONTOH, jangan di-load langsung.
// Copy salah satu opsi di bawah ke file dashboard Caelestia kamu.
//
// OPSI A (disarankan): Tambah tab baru di modules/dashboard/Content.qml
// ─────────────────────────────────────────────────────────────────────
// 1. Import di atas Content.qml:
//    import "../custom/TimerWidget.qml" as TimerWidget  // atau via Loader
//
// 2. Tambahkan entry ke `dashboardTabs` (sejajar Dashboard/Media/Performance):
//
//    readonly property var dashboardTabs: {
//        const allTabs = [
//            { component: dashComponent, iconName: "dashboard", text: qsTr("Dashboard"), enabled: Config.dashboard.showDashboard },
//            // ... tab bawaan lain ...
//            {
//                component: focusComponent,
//                iconName: "timer",
//                text: qsTr("Fokus"),
//                enabled: true
//            }
//        ];
//        return allTabs.filter(tab => tab.enabled);
//    }
//
// 3. Definisikan komponennya (sejajar dashComponent/mediaComponent):
//
//    Component {
//        id: focusComponent
//        RowLayout {
//            spacing: Appearance.spacing.normal
//            TimerWidget {}
//            TodoWidget {}
//        }
//    }
//
//    Catatan import: karena Content.qml ada di modules/dashboard/,
//    panggil widget via relative path atau daftarkan di qmldir.
//    Paling gampang: taruh file di modules/custom/ lalu import "../custom/TimerWidget.qml".
//
//
// OPSI B: Sisip langsung ke dalam tab Dashboard (modules/dashboard/dash/Dash.qml)
// ─────────────────────────────────────────────────────────────────────
//    RowLayout {
//        Layout.fillWidth: true
//        spacing: Appearance.spacing.normal
//        TimerWidget { Layout.fillWidth: true }
//        TodoWidget { Layout.fillWidth: true }
//    }
//
//
// OPSI C: Standalone test tanpa Caelestia (debug cepat)
// ─────────────────────────────────────────────────────────────────────
//    Jalankan: qs -p /path/ke/TimerWidget.qml
//    Untuk TodoWidget yang butuh Paths.home, mock dulu atau load dalam shell penuh.
