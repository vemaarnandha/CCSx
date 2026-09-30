// EventPopover.qml — two-phase add/list dialog for one calendar date.
//
// LIST phase: event rows for dateKey + empty state + full-width "Add event"
// pill that switches to FORM. FORM phase: title field + hour/minute steppers
// + AM/PM pills + Save/Cancel + "< Back" link returning to LIST.
//
// Data lives in EventService (single source of truth); this file only renders
// the projection for dateKey and forwards actions. Dialog pattern mirrors
// TodoWidget.qml: scrim StyledRect m3scrim opacity 0.6 + centered card,
// Keys.onPressed Esc, focus on show, Behavior on opacity.
//
// Default new-event time is 9:00 AM — a sane morning default that keeps the
// form predictable (no wall-clock rounding surprises).
// Wrap-with-carry: StyledSpinBox clamps at from/to (its increase/decrease use
// Math.min/Math.max), so wrapping is implemented in onValueModified by
// comparing the new spinner value against the stored root.hourVal /
// root.minuteVal (the pre-press value): a clamped landing at the boundary
// when old +/- step would cross it means the user pressed past the edge, so
// we wrap (minute 55 +5 -> 0 + hour+1, hour 12 +1 -> 1, and mirrors for -).
// Free typing still accepts any 1-12 / 0-59; Save normalizes with modulo.

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    // "YYYY-MM-DD" key of the selected day. Empty means "no selection".
    property string dateKey: ""
    property bool show: false
    // false = LIST phase, true = FORM phase.
    property bool showForm: false

    signal close()

    // Projection of the service list for this date. Guarded so first frames
    // before the singleton loads don't spam WARN.
    readonly property var events: (EventService.list ?? []).filter(function(ev) {
        return ev && ev.date === root.dateKey;
    })
    // Past-date detection: lexical compare works for zero-padded keys.
    // Guarded so an empty dateKey never counts as past.
    readonly property bool isPast: root.dateKey !== "" && root.dateKey < EventService.todayKey()
    readonly property int eventCount: (root.events ?? []).length
    // Human-friendly header ("Tue, 20 Oct 2026") parsed from the key.
    // Guarded: split of "" yields [""], so only parse when non-empty.
    readonly property string prettyDate: {
        if (root.dateKey === "")
            return qsTr("Events");
        const p = root.dateKey.split("-");
        if (p.length !== 3)
            return root.dateKey;
        const d = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
        return Qt.formatDate(d, "ddd, d MMM yyyy");
    }

    // FORM state. isPM=false means the default is AM.
    property int hourVal: 9
    property int minuteVal: 0
    property bool isPM: false

    visible: opacity > 0
    opacity: root.show ? 1 : 0

    Behavior on opacity {
        Anim {}
    }

    // Esc closes the popover and resets to LIST.
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape && root.show) {
            root.resetAndClose();
            event.accepted = true;
        }
    }

    // Clear inputs and return to LIST whenever a new date is selected.
    onDateKeyChanged: {
        root.resetForm();
        root.showForm = false;
    }

    // Stored "HH:MM" (24h) -> "h:MM AM/PM" for list rows. Falls back to the
    // raw string when unparseable.
    function to12h(hhmm): string {
        if ((hhmm ?? "") === "")
            return "";
        const parts = String(hhmm).split(":");
        if (parts.length !== 2)
            return String(hhmm);
        const h24 = Number(parts[0]);
        const m = Number(parts[1]);
        if (isNaN(h24) || isNaN(m))
            return String(hhmm);
        const suffix = h24 >= 12 ? "PM" : "AM";
        let h12 = h24 % 12;
        if (h12 === 0)
            h12 = 12;
        const mm = String(m).padStart(2, "0");
        return h12 + ":" + mm + " " + suffix;
    }

    function resetForm(): void {
        titleForm.text = "";
        root.hourVal = 9;
        root.minuteVal = 0;
        root.isPM = false;
        // Explicit write-back: StyledSpinBox.increase/decrease assign
        // `value` in JS, which severs the `value: root.*Val` binding on
        // first press — without this the boxes stop following resets.
        hourBox.value = 9;
        minuteBox.value = 0;
    }

    function resetAndClose(): void {
        root.resetForm();
        root.showForm = false;
        root.close();
    }

    function submitForm(): void {
        const title = titleForm.text.trim();
        if (title.length === 0 || root.isPast || root.dateKey === "")
            return;
        // Normalize free-typed values, then convert 12h -> 24h "HH:MM".
        const h12 = ((Math.round(root.hourVal) - 1) % 12 + 12) % 12 + 1;
        const min = ((Math.round(root.minuteVal) % 60) + 60) % 60;
        const h24 = (h12 % 12) + (root.isPM ? 12 : 0);
        const hhmm = String(h24).padStart(2, "0") + ":" + String(min).padStart(2, "0");
        EventService.addEvent(root.dateKey, title, hhmm);
        root.resetForm();
        root.showForm = false;
    }

    // Scrim (click to dismiss, resets to LIST). Kept near-opaque so the
    // busy calendar grid behind never bleeds through the dialog.
    StyledRect {
        anchors.fill: parent
        radius: 0
        color: Colours.palette.m3scrim
        opacity: 0.85
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.resetAndClose()
        }
    }

    // Centered card. Same fill as the other Dash cards
    // (tPalette.m3surfaceContainer) + outline so it stays distinct on
    // glassy themes without looking foreign.
    StyledRect {
        id: card

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        implicitHeight: cardLayout.implicitHeight + Tokens.padding.large * 2
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainer
        border.width: 1
        border.color: Colours.palette.m3outlineVariant

        // Card click must not fall through to the scrim.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onClicked: mouse => mouse.accepted = true
        }

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.small

            // Header: icon + date + close.
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "event"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.medium
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.prettyDate
                    font: Tokens.font.title.medium
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }
                StyledText {
                    visible: root.eventCount > 0
                    text: qsTr("%1 event(s)").arg(root.eventCount)
                    color: Colours.palette.m3onSurfaceVariant
                }
                MaterialIcon {
                    text: "close"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetAndClose()
                    }
                }
            }

            // ---------- LIST phase ----------
            ColumnLayout {
                Layout.fillWidth: true
                visible: !root.showForm
                spacing: Tokens.spacing.small

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 170

                    ListView {
                        id: eventList
                        anchors.fill: parent
                        clip: true
                        spacing: Tokens.spacing.small
                        boundsBehavior: Flickable.StopAtBounds
                        model: (root.events ?? []).length

                        delegate: StyledRect {
                            required property int index
                            readonly property var entry: (root.events ?? [])[index] ?? ({ id: "", title: "", time: "", done: false })

                            width: ListView.view.width
                            implicitHeight: 56
                            radius: Tokens.rounding.medium
                            color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.small
                                anchors.rightMargin: Tokens.padding.small
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    text: entry.done ? "check_circle" : "radio_button_unchecked"
                                    fill: entry.done ? 1 : 0
                                    color: entry.done ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                    fontStyle: Tokens.font.icon.small
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: EventService.toggleDone(entry.id)
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: entry.title
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        color: entry.done ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                                        font.strikeout: entry.done
                                        opacity: entry.done ? 0.6 : 1.0
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: EventService.toggleDone(entry.id)
                                        }
                                    }
                                    StyledText {
                                        visible: (entry.time ?? "") !== ""
                                        text: root.to12h(entry.time)
                                        color: Colours.palette.m3onSurfaceVariant
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
                                        onClicked: EventService.deleteEvent(entry.id)
                                    }
                                }
                            }
                        }
                    }

                    // Empty placeholder (icon + text, centered).
                    Column {
                        anchors.centerIn: parent
                        visible: (root.events ?? []).length === 0
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "event_note"
                            fontStyle: Tokens.font.icon.extraLarge
                            color: Colours.palette.m3onSurfaceVariant
                        }
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("No events for this day")
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }

                // Full-width "Add event" pill switching to FORM.
                StyledRect {
                    id: addEventPill
                    Layout.fillWidth: true
                    Layout.minimumHeight: 40
                    implicitHeight: 44
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3primary
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.extraSmall
                        MaterialIcon {
                            text: "add"
                            color: Colours.palette.m3onPrimary
                            fontStyle: Tokens.font.icon.small
                        }
                        StyledText {
                            text: qsTr("Add event")
                            color: Colours.palette.m3onPrimary
                        }
                    }
                    StateLayer {
                        anchors.fill: parent
                        onClicked: {
                            root.resetForm();
                            root.showForm = true;
                            titleForm.forceActiveFocus();
                        }
                        color: Colours.palette.m3onPrimary
                    }
                }
            }

            // ---------- FORM phase ----------
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.showForm
                spacing: Tokens.spacing.small

                StyledTextField {
                    id: titleForm
                    Layout.fillWidth: true
                    placeholderText: qsTr("Event title")
                    focus: root.show && root.showForm
                    onAccepted: root.submitForm()
                }

                // Time row: hour stepper + colon + minute stepper. Both boxes
                // are fillWidth (no fixed widths anywhere in this dialog) so
                // the row can never overflow past the card on narrow
                // calendars — layouts do not shrink fixed-width siblings.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledSpinBox {
                        id: hourBox
                        Layout.fillWidth: true
                        // Wide range 0..13 (not 1..12): every press changes
                        // the value, so onValueChanged always fires — the
                        // control clamps silently at bounds and the custom
                        // IconButton indicators never mirror `up.pressed`,
                        // so bound-gated wrapping can never trigger.
                        // Out-of-range values wrap below; typing stays
                        // in-range via valueFromText, so typed values never
                        // wrap unexpectedly.
                        from: 0
                        to: 13
                        stepSize: 1
                        value: root.hourVal
                        cLayer: 1
                        valueFromText: function(t, locale) {
                            const n = Math.round(Number(t));
                            if (isNaN(n))
                                return root.hourVal;
                            return Math.min(12, Math.max(1, n));
                        }
                        onValueChanged: {
                            const v = hourBox.value;
                            if (v > 12)
                                root.hourVal = 1;
                            else if (v < 1)
                                root.hourVal = 12;
                            else
                                root.hourVal = v;
                            hourBox.value = root.hourVal;
                        }
                    }
                    StyledText {
                        text: ":"
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.title.medium
                    }
                    StyledSpinBox {
                        id: minuteBox
                        Layout.fillWidth: true
                        // Wide range -5..64 (not 0..59): same reason as
                        // hourBox above — every press changes the value, so
                        // wrapping via onValueChanged just works, both ways.
                        from: -5
                        to: 64
                        stepSize: 5
                        value: root.minuteVal
                        cLayer: 1
                        textFromValue: function(v, locale) {
                            return String(Math.round(v)).padStart(2, "0");
                        }
                        valueFromText: function(t, locale) {
                            const n = Math.round(Number(t));
                            if (isNaN(n))
                                return 0;
                            return Math.min(59, Math.max(0, n));
                        }
                        onValueChanged: {
                            const v = minuteBox.value;
                            if (v > 59) {
                                // Wrapped past 59: carry +1 hour (12 wraps to 1).
                                root.minuteVal = v - 60;
                                root.hourVal = root.hourVal >= 12 ? 1 : root.hourVal + 1;
                                hourBox.value = root.hourVal;
                            } else if (v < 0) {
                                // Wrapped below 0: borrow -1 hour (1 wraps to 12).
                                root.minuteVal = v + 60;
                                root.hourVal = root.hourVal <= 1 ? 12 : root.hourVal - 1;
                                hourBox.value = root.hourVal;
                            } else {
                                root.minuteVal = v;
                            }
                            minuteBox.value = root.minuteVal;
                        }
                    }
                }

                // AM/PM row: two half-width pills on their own row so
                // nothing overflows past the card onto Resources.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    // AM pill.
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.minimumHeight: 40
                        implicitHeight: 40
                        radius: Tokens.rounding.full
                        color: !root.isPM ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                        StyledText {
                            anchors.centerIn: parent
                            text: qsTr("AM")
                            color: !root.isPM ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        }
                        StateLayer {
                            anchors.fill: parent
                            onClicked: root.isPM = false
                            color: !root.isPM ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        }
                    }
                    // PM pill.
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.minimumHeight: 40
                        implicitHeight: 40
                        radius: Tokens.rounding.full
                        color: root.isPM ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                        StyledText {
                            anchors.centerIn: parent
                            text: qsTr("PM")
                            color: root.isPM ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        }
                        StateLayer {
                            anchors.fill: parent
                            onClicked: root.isPM = true
                            color: root.isPM ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        }
                    }
                }

                // Save + Cancel pills: full-width pair (same pattern as the
                // AM/PM row) so neither can overflow the card.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small
                    // Cancel pill.
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.minimumHeight: 40
                        implicitWidth: 84
                        implicitHeight: 40
                        radius: Tokens.rounding.full
                        color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                        StyledText {
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            color: Colours.palette.m3onSurface
                        }
                        StateLayer {
                            anchors.fill: parent
                            onClicked: root.resetAndClose()
                            color: Colours.palette.m3onSurface
                        }
                    }
                    // Save pill (disabled for past dates / empty title).
                    StyledRect {
                        id: savePill
                        Layout.fillWidth: true
                        Layout.minimumHeight: 40
                        implicitWidth: 84
                        implicitHeight: 40
                        radius: Tokens.rounding.full
                        color: savePill.canSave ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
                        opacity: savePill.canSave ? 1.0 : 0.6
                        property bool canSave: !root.isPast && titleForm.text.trim().length > 0
                        StyledText {
                            anchors.centerIn: parent
                            text: qsTr("Save")
                            color: savePill.canSave ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        }
                        StateLayer {
                            anchors.fill: parent
                            onClicked: root.submitForm()
                            color: savePill.canSave ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        }
                    }
                }

                // "< Back" link returning to LIST with inputs reset.
                StyledText {
                    text: qsTr("< Back")
                    color: Colours.palette.m3primary
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.resetForm();
                            root.showForm = false;
                        }
                    }
                }
            }

            // Past-date hint (both phases).
            StyledText {
                Layout.fillWidth: true
                visible: root.isPast
                text: qsTr("Past dates cannot have new events.")
                color: Colours.palette.m3error
                wrapMode: Text.WordWrap
            }
        }
    }
}
