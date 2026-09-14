import QtQuick 2.12

// Per-app context menu, opened by holding OK on a grid tile.
// Fully D-pad navigable: Up/Down moves between rows, Left/Right edits the
// tint/icon rows, OK activates, Back/Escape closes.

FocusScope {
    id: menu

    property var entry: ({ appId: "", name: "", hidden: false, tint: "", icon: "" })
    property var tintChoices: []
    property var iconChoices: []

    signal hideToggle()
    signal renameRequested()
    signal tintPicked(string tint)
    signal iconPicked(string path)
    signal settingsRequested()
    signal resetRequested()
    signal closed()

    FontLoader { id: bodyFontLoader; source: "../../assets/fonts/body.ttf" }
    function bodyFont() { return bodyFontLoader.name || "" }

    property int row: 0
    readonly property int rowCount: 7

    property int tintIndex: Math.max(0, menu.tintChoices.indexOf(menu.entry.tint))
    property int iconIndex: {
        for (var i = 0; i < menu.iconChoices.length; i++)
            if (menu.iconChoices[i].path === menu.entry.icon) return i
        return 0
    }

    anchors.fill: parent
    visible: false
    focus: true
    z: 100

    // Dim backdrop
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.55
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: 560
        height: column.implicitHeight + 48
        radius: 18
        color: "#1e1e2e"
        border.color: "#45475a"
        border.width: 2

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 24
            spacing: 6

            Text {
                width: parent.width
                text: menu.entry.name !== "" ? menu.entry.name : menu.entry.appId
                color: "#cdd6f4"
                font.family: menu.bodyFont()
                font.pixelSize: 22
                font.weight: Font.Bold
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                width: parent.width
                text: menu.entry.appId
                color: "#6c7086"
                font.family: menu.bodyFont()
                font.pixelSize: 12
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
            }

            // 0: Hide / Show
            Rectangle {
                width: parent.width; height: 52; radius: 10
                color: menu.row === 0 ? "#313244" : "transparent"
                border.color: menu.row === 0 ? "#cba6f7" : "transparent"
                border.width: menu.row === 0 ? 2 : 0
                Text {
                    anchors.centerIn: parent
                    text: menu.entry.hidden ? "Show app" : "Hide app"
                    color: "#cdd6f4"; font.family: menu.bodyFont(); font.pixelSize: 20
                }
            }

            // 1: Rename
            Rectangle {
                width: parent.width; height: 52; radius: 10
                color: menu.row === 1 ? "#313244" : "transparent"
                border.color: menu.row === 1 ? "#cba6f7" : "transparent"
                border.width: menu.row === 1 ? 2 : 0
                Text {
                    anchors.centerIn: parent
                    text: "Rename…"
                    color: "#cdd6f4"; font.family: menu.bodyFont(); font.pixelSize: 20
                }
            }

            // 2: Tint swatches
            Rectangle {
                width: parent.width; height: 56; radius: 10
                color: menu.row === 2 ? "#313244" : "transparent"
                border.color: menu.row === 2 ? "#cba6f7" : "transparent"
                border.width: menu.row === 2 ? 2 : 0

                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    Repeater {
                        model: menu.tintChoices
                        delegate: Rectangle {
                            width: 30; height: 30; radius: 15
                            color: modelData === "" ? "#45475a" : modelData
                            border.color: index === menu.tintIndex ? "#ffffff" : "transparent"
                            border.width: index === menu.tintIndex ? 3 : 0
                            Text {
                                anchors.centerIn: parent
                                visible: modelData === ""
                                text: "×"; color: "#cdd6f4"; font.pixelSize: 16
                            }
                        }
                    }
                }
            }

            // 3: Icon cycler
            Rectangle {
                width: parent.width; height: 52; radius: 10
                color: menu.row === 3 ? "#313244" : "transparent"
                border.color: menu.row === 3 ? "#cba6f7" : "transparent"
                border.width: menu.row === 3 ? 2 : 0
                Text {
                    anchors.centerIn: parent
                    text: "◀  Icon: " + (menu.iconChoices[menu.iconIndex] ? menu.iconChoices[menu.iconIndex].name : "") + "  ▶"
                    color: "#cdd6f4"; font.family: menu.bodyFont(); font.pixelSize: 20
                }
            }

            // 4: Settings
            Rectangle {
                width: parent.width; height: 52; radius: 10
                color: menu.row === 4 ? "#313244" : "transparent"
                border.color: menu.row === 4 ? "#cba6f7" : "transparent"
                border.width: menu.row === 4 ? 2 : 0
                Text {
                    anchors.centerIn: parent
                    text: "Settings"
                    color: "#89b4fa"; font.family: menu.bodyFont(); font.pixelSize: 20
                }
            }

            // 5: Reset
            Rectangle {
                width: parent.width; height: 52; radius: 10
                color: menu.row === 5 ? "#313244" : "transparent"
                border.color: menu.row === 5 ? "#cba6f7" : "transparent"
                border.width: menu.row === 5 ? 2 : 0
                Text {
                    anchors.centerIn: parent
                    text: "Reset to defaults"
                    color: "#f38ba8"; font.family: menu.bodyFont(); font.pixelSize: 20
                }
            }

            // 6: Close
            Rectangle {
                width: parent.width; height: 52; radius: 10
                color: menu.row === 6 ? "#313244" : "transparent"
                border.color: menu.row === 6 ? "#cba6f7" : "transparent"
                border.width: menu.row === 6 ? 2 : 0
                Text {
                    anchors.centerIn: parent
                    text: "Close"
                    color: "#a6adc8"; font.family: menu.bodyFont(); font.pixelSize: 20
                }
            }
        }
    }

    property int _armedKey: 0
    property bool _ignoreUntilRelease: false

    function isActivateKey(key) {
        return key === Qt.Key_Return || key === Qt.Key_Enter ||
               key === Qt.Key_Space || key === Qt.Key_Select
    }
    function isBackKey(key) {
        // 18874371 == 0x01200003 is the webOS remote Back key (LG calls it ir_key_back)
        return key === Qt.Key_Back || key === Qt.Key_Escape ||
               key === Qt.Key_Cancel || key === 18874371
    }
    function editLeft() {
        if (menu.row === 2) {
            menu.tintIndex = (menu.tintIndex - 1 + menu.tintChoices.length) % menu.tintChoices.length
            menu.tintPicked(menu.tintChoices[menu.tintIndex])
        } else if (menu.row === 3) {
            menu.iconIndex = (menu.iconIndex - 1 + menu.iconChoices.length) % menu.iconChoices.length
            menu.iconPicked(menu.iconChoices[menu.iconIndex].path)
        }
    }
    function editRight() {
        if (menu.row === 2) {
            menu.tintIndex = (menu.tintIndex + 1) % menu.tintChoices.length
            menu.tintPicked(menu.tintChoices[menu.tintIndex])
        } else if (menu.row === 3) {
            menu.iconIndex = (menu.iconIndex + 1) % menu.iconChoices.length
            menu.iconPicked(menu.iconChoices[menu.iconIndex].path)
        }
    }

    // Activate on key *release* and only for a press we saw while focused, so the
    // held key that opened the menu (or its auto-repeat) can't trigger a row.
    Keys.onPressed: {
        if (menu.isBackKey(event.key)) { menu.closed(); event.accepted = true; return }
        // Swallow the key that opened the menu until it is released
        if (menu._ignoreUntilRelease && menu.isActivateKey(event.key)) { event.accepted = true; return }
        switch (event.key) {
        case Qt.Key_Up: menu.row = Math.max(0, menu.row - 1); event.accepted = true; break
        case Qt.Key_Down: menu.row = Math.min(menu.rowCount - 1, menu.row + 1); event.accepted = true; break
        case Qt.Key_Left: menu.editLeft(); event.accepted = true; break
        case Qt.Key_Right: menu.editRight(); event.accepted = true; break
        default:
            if (menu.isActivateKey(event.key)) {
                menu._armedKey = event.key
                event.accepted = true
            }
        }
    }
    Keys.onReleased: {
        if (menu.isActivateKey(event.key)) {
            if (menu._ignoreUntilRelease) {
                menu._ignoreUntilRelease = false
                menu._armedKey = 0
            } else if (menu._armedKey === event.key) {
                menu._armedKey = 0
                menu.activate()
            } else {
                menu._armedKey = 0
            }
            event.accepted = true
        }
    }

    function activate() {
        switch (menu.row) {
        case 0: menu.hideToggle(); break
        case 1: menu.renameRequested(); break
        case 4: menu.settingsRequested(); break
        case 5: menu.resetRequested(); break
        case 6: menu.closed(); break
        }
    }

    function open(keyHeld, initialRow) {
        menu._ignoreUntilRelease = (keyHeld === true)
        menu._armedKey = 0
        menu.row = Math.max(0, Math.min(menu.rowCount - 1, initialRow === undefined ? 0 : initialRow))
        menu.tintIndex = Math.max(0, menu.tintChoices.indexOf(menu.entry.tint))
        menu.visible = true
        menu.forceActiveFocus()
    }

    function close() {
        menu.visible = false
    }
}
