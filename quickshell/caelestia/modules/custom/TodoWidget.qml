// TodoWidget.qml — To-Do List QML-only dengan persistensi JSON untuk caelestia-shell
// Lokasi aktif: ~/.config/quickshell/caelestia/modules/custom/TodoWidget.qml
// Data: ~/.config/quickshell/caelestia/todos.json (dibuat otomatis saat pertama save)
// Pola: ListModel (reaktif) + FileView (baca/tulis file) + debounce Timer (hemat I/O).
// Tanpa Python, tanpa IPC Niri — murni Quickshell.Io, cocok untuk Hyprland.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

StyledRect {
    id: root

    radius: Tokens.rounding.large
    color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
    implicitWidth: 300
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    // ── Model reaktif (sumber kebenaran untuk ListView) ──
    // Tiap item: { "text": string, "done": bool }
    ListModel {
        id: todos
    }

    // Guard agar tidak save saat loading awal.
    property bool ready: false

    // ── Persistensi file ──
    FileView {
        id: store
        // Paths.home berasal dari qs.utils (pola resmi Caelestia).
        path: Paths.home + "/.config/quickshell/caelestia/todos.json"
        printErrors: false
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        onLoadedChanged: loadFromDisk()
    }

    // Tulis ke disk, di-debounce 400ms agar tidak write tiap aksi.
    Timer {
        id: saveDebounce
        interval: 400
        repeat: false
        onTriggered: root.saveToDisk()
    }
    function requestSave(): void {
        if (!root.ready)
            return;
        saveDebounce.restart();
    }

    // Muat JSON → ListModel. Toleran terhadap file kosong / korup / belum ada.
    function loadFromDisk(): void {
        todos.clear();
        let raw = "";
        try {
            raw = store.text();
        } catch (e) {
            raw = "";
        }
        if (!raw || raw.trim().length === 0) {
            root.ready = true;
            return;
        }
        try {
            const arr = JSON.parse(raw);
            if (Array.isArray(arr)) {
                for (let i = 0; i < arr.length; i++) {
                    const it = arr[i];
                    if (it && typeof it.text === "string")
                        todos.append({ text: it.text, done: !!it.done });
                }
            }
        } catch (e) {
            console.warn("[TodoWidget] todos.json korup, mulai dari kosong:", e);
        }
        root.ready = true;
    }

    // Simpan ListModel → JSON array.
    function saveToDisk(): void {
        const arr = [];
        for (let i = 0; i < todos.count; i++)
            arr.push(todos.get(i));
        try {
            store.setText(JSON.stringify(arr, null, 2));
        } catch (e) {
            console.warn("[TodoWidget] gagal menyimpan:", e);
        }
    }

    // ── CRUD ──
    function addTodo(text: string): void {
        const t = text.trim();
        if (t.length === 0)
            return;
        todos.append({ text: t, done: false });
        requestSave();
    }
    function toggleTodo(index: int): void {
        if (index < 0 || index >= todos.count)
            return;
        const cur = todos.get(index);
        todos.set(index, { text: cur.text, done: !cur.done });
        requestSave();
    }
    function removeTodo(index: int): void {
        if (index < 0 || index >= todos.count)
            return;
        todos.remove(index);
        requestSave();
    }
    function clearDone(): void {
        for (let i = todos.count - 1; i >= 0; i--) {
            if (todos.get(i).done)
                todos.remove(i);
        }
        requestSave();
    }

    Component.onCompleted: loadFromDisk()

    // ── Tampilan ──
    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            MaterialIcon {
                text: "checklist"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.medium
            }
            StyledText {
                text: qsTr("To-Do")
                font: Tokens.font.title.small
                color: Colours.palette.m3onSurface
                Layout.fillWidth: true
            }
            StyledText {
                // counter "2/5"
                text: {
                    let done = 0;
                    for (let i = 0; i < todos.count; i++)
                        if (todos.get(i).done)
                            done++;
                    return done + "/" + todos.count;
                }
                color: Colours.palette.m3onSurfaceVariant
            }
        }

        // Input + tombol add
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledTextField {
                id: input
                Layout.fillWidth: true
                placeholderText: qsTr("Tugas baru…")
                onAccepted: {
                    root.addTodo(text);
                    text = "";
                }
            }
            StyledRect {
                implicitWidth: 44
                implicitHeight: 38
                radius: Tokens.rounding.full
                color: Colours.palette.m3primary
                MaterialIcon {
                    anchors.centerIn: parent
                    text: "add"
                    color: Colours.palette.m3onPrimary
                }
                StateLayer {
                    anchors.fill: parent
                    onClicked: {
                        root.addTodo(input.text);
                        input.text = "";
                    }
                    color: Colours.palette.m3onPrimary
                }
            }
        }

        // Daftar tugas
        ListView {
            id: list
            Layout.fillWidth: true
            // Tinggi adaptif: max ~5 item terlihat, selebihnya scroll.
            Layout.preferredHeight: Math.min(contentHeight, 5 * 44 + spacing * 5)
            clip: true
            spacing: Tokens.spacing.small
            model: todos
            boundsBehavior: Flickable.StopAtBounds

            StyledText {
                anchors.centerIn: parent
                visible: todos.count === 0
                text: qsTr("Belum ada tugas")
                color: Colours.palette.m3onSurfaceVariant
            }

            delegate: StyledRect {
                id: row
                required property int index
                required property string text
                required property bool done

                width: list.width
                implicitHeight: 44
                radius: Tokens.rounding.medium
                color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.small
                    anchors.rightMargin: Tokens.padding.small
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: row.done ? "check_circle" : "radio_button_unchecked"
                        fill: row.done ? 1 : 0
                        color: row.done ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleTodo(row.index)
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: row.text
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        color: row.done ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                        font.strikeout: row.done
                        opacity: row.done ? 0.6 : 1.0
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleTodo(row.index)
                        }
                    }

                    MaterialIcon {
                        text: "delete"
                        color: Colours.palette.m3error
                        fontStyle: Tokens.font.icon.small
                        opacity: delHover.containsMouse ? 1.0 : 0.6
                        MouseArea {
                            id: delHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.removeTodo(row.index)
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: todos.count > 0
            text: qsTr("Hapus yang selesai")
            color: Colours.palette.m3error
            font.underline: true
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clearDone()
            }
        }
    }
}
