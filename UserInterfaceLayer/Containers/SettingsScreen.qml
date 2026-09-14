import QtQuick 2.12

// Global settings screen, reached from the per-app long-press menu.
// D-pad: Up/Down move, Left/Right adjust, OK activates/toggles, Back returns.

FocusScope {
    id: settings

    property var appSettings: null

    signal manageRequested()
    signal backRequested()
    signal textRequested(string key, string initial)

    FontLoader { id: bodyFontLoader; source: "../../assets/fonts/body.ttf" }
    function bodyFont() { return bodyFontLoader.name || "" }

    readonly property var rows: [
        { type: "action", label: "Manage all apps" },
        { type: "toggle", label: "Auto-hide new apps", key: "autoHideNewApps" },
        { type: "toggle", label: "24-hour clock", key: "clock24h" },
        { type: "toggle", label: "Show AM/PM", key: "showAmPm" },
        { type: "toggle", label: "Blinking colon", key: "flashSeparator" },
        { type: "choice", label: "Temperature", key: "weatherUnit", values: ["C", "F"] },
        { type: "text", label: "Greeter name", key: "greeterName" },
        { type: "toggle", label: "Background shader", key: "constellationEnabled" },
        { type: "number", label: "Shader density", key: "constellationScale", min: 3.0, max: 12.0, step: 0.5, decimals: 1 },
        { type: "number", label: "Shader edge width", key: "constellationLineWidth", min: 0.005, max: 0.03, step: 0.002, decimals: 3 },
        { type: "number", label: "Shader speed", key: "constellationSpeed", min: 0.0, max: 2.0, step: 0.1, decimals: 1 },
        { type: "number", label: "Shader opacity", key: "constellationAlpha", min: 0.1, max: 1.0, step: 0.05, decimals: 2 },
        { type: "toggle", label: "Tint background with app", key: "constellationTintFromApp" },
        { type: "action", label: "Close" }
    ]

    property int row: 0
    property int _armedKey: 0
    property bool _ignoreUntilRelease: false

    function isActivateKey(key) {
        return key === Qt.Key_Return || key === Qt.Key_Enter ||
               key === Qt.Key_Space || key === Qt.Key_Select
    }
    function isBackKey(key) {
        return key === Qt.Key_Back || key === Qt.Key_Escape ||
               key === Qt.Key_Cancel || key === 18874371
    }

    function rowValue(r) {
        if (!appSettings) return ""
        if (r.type === "toggle") return appSettings[r.key] ? "On" : "Off"
        if (r.type === "choice") return r.values.indexOf(appSettings[r.key]) >= 0 ? appSettings[r.key] : r.values[0]
        if (r.type === "number") return Number(appSettings[r.key]).toFixed(r.decimals)
        if (r.type === "text") {
            var v = appSettings[r.key]
            return (v === undefined || v === null) ? "" : String(v)
        }
        return ""
    }

    function adjust(delta) {
        if (!appSettings) return
        var r = rows[row]
        if (r.type === "text") return
        if (r.type === "toggle") {
            appSettings[r.key] = !appSettings[r.key]
        } else if (r.type === "choice") {
            var i = r.values.indexOf(appSettings[r.key])
            if (i < 0) i = 0
            i = (i + (delta > 0 ? 1 : r.values.length - 1)) % r.values.length
            appSettings[r.key] = r.values[i]
        } else if (r.type === "number") {
            var v = Number(appSettings[r.key]) + delta * r.step
            v = Math.max(r.min, Math.min(r.max, v))
            appSettings[r.key] = v
        } else {
            return
        }
        appSettings.save()
    }

    function activate() {
        var r = rows[row]
        if (r.type === "action") {
            if (r.label === "Manage all apps") settings.manageRequested()
            else settings.backRequested()
        } else if (r.type === "text") {
            var v = appSettings ? appSettings[r.key] : ""
            if (v === undefined || v === null) v = ""
            settings.textRequested(r.key, String(v))
        } else {
            adjust(1)
        }
    }

    anchors.fill: parent
    visible: false
    focus: true
    z: 115

    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.6 }

    Rectangle {
        anchors.centerIn: parent
        width: 760
        height: parent.height * 0.9
        radius: 18
        color: "#1e1e2e"
        border.color: "#45475a"
        border.width: 2

        Text {
            id: title
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 20
            text: "Settings"
            color: "#cdd6f4"
            font.family: settings.bodyFont()
            font.pixelSize: 24
            font.weight: Font.Bold
        }

        Flickable {
            id: flick
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: title.bottom
            anchors.bottom: parent.bottom
            anchors.margins: 20
            anchors.topMargin: 14
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: list.implicitHeight

        Column {
            id: list
            width: flick.width
            spacing: 4

            Repeater {
                model: settings.rows
                delegate: Rectangle {
                    width: list.width
                    height: 48
                    radius: 10
                    color: settings.row === index ? "#313244" : "transparent"
                    border.color: settings.row === index ? "#cba6f7" : "transparent"
                    border.width: settings.row === index ? 2 : 0

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: modelData.type === "action" ? "#89b4fa" : "#cdd6f4"
                        font.family: settings.bodyFont()
                        font.pixelSize: 19
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.type !== "action"
                        text: settings.rowValue(modelData)
                        color: "#a6e3a1"
                        font.family: settings.bodyFont()
                        font.pixelSize: 18
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: { settings.row = index; settings.ensureVisible(); settings.activate() }
                    }
                }
            }
        }
        }
    }

    Keys.onPressed: {
        if (settings.isBackKey(event.key)) { settings.backRequested(); event.accepted = true; return }
        if (settings._ignoreUntilRelease && settings.isActivateKey(event.key)) { event.accepted = true; return }
        switch (event.key) {
        case Qt.Key_Up:
            settings.row = Math.max(0, settings.row - 1)
            settings.ensureVisible()
            event.accepted = true; break
        case Qt.Key_Down:
            settings.row = Math.min(settings.rows.length - 1, settings.row + 1)
            settings.ensureVisible()
            event.accepted = true; break
        case Qt.Key_Left: settings.adjust(-1); event.accepted = true; break
        case Qt.Key_Right: settings.adjust(1); event.accepted = true; break
        default:
            if (settings.isActivateKey(event.key)) { settings._armedKey = event.key; event.accepted = true }
        }
    }
    Keys.onReleased: {
        if (settings.isActivateKey(event.key)) {
            if (settings._ignoreUntilRelease) {
                settings._ignoreUntilRelease = false
                settings._armedKey = 0
            } else if (settings._armedKey === event.key) {
                settings._armedKey = 0
                settings.activate()
            } else {
                settings._armedKey = 0
            }
            event.accepted = true
        }
    }

    function open(keyHeld) {
        settings._ignoreUntilRelease = (keyHeld === true)
        settings._armedKey = 0
        settings.row = 0
        flick.contentY = 0
        settings.visible = true
        settings.forceActiveFocus()
    }
    function close() { settings.visible = false }

    function ensureVisible() {
        var y0 = settings.row * 52
        if (y0 < flick.contentY) flick.contentY = y0
        else if (y0 + 48 > flick.contentY + flick.height) flick.contentY = y0 + 48 - flick.height
    }
}
