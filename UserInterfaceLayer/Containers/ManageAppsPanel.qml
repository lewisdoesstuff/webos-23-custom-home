import QtQuick 2.12

// "Manage all apps" panel: lists every launch point (including hidden ones)
// so hidden apps can always be restored, plus a reorder entry.
// D-pad: Up/Down moves, OK toggles/opens, Back returns.

FocusScope {
    id: panelRoot

    property var appsModel: null       // ListModel { appId, name, hidden }

    signal toggleRequested(string appId)
    signal reorderRequested()
    signal closed()
    signal backRequested()

    FontLoader { id: bodyFontLoader; source: "../../assets/fonts/body.ttf" }
    function bodyFont() { return bodyFontLoader.name || "" }

    property int sel: 0                // 0 = reorder row, 1..n = app rows
    property int appCount: appsModel ? appsModel.count : 0
    property int _armedKey: 0

    function isActivateKey(key) {
        return key === Qt.Key_Return || key === Qt.Key_Enter ||
               key === Qt.Key_Space || key === Qt.Key_Select
    }
    function isBackKey(key) {
        return key === Qt.Key_Back || key === Qt.Key_Escape ||
               key === Qt.Key_Cancel || key === 18874371
    }

    anchors.fill: parent
    visible: false
    focus: true
    z: 110

    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.6 }

    Rectangle {
        anchors.centerIn: parent
        width: 720
        height: parent.height * 0.85
        radius: 18
        color: "#1e1e2e"
        border.color: "#45475a"
        border.width: 2

        Text {
            id: title
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 16
            text: "Manage all apps"
            color: "#cdd6f4"
            font.family: panelRoot.bodyFont()
            font.pixelSize: 24
            font.weight: Font.Bold
        }

        Rectangle {
            id: reorderRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: title.bottom
            anchors.margins: 20
            anchors.topMargin: 12
            height: 52
            radius: 10
            color: panelRoot.sel === 0 ? "#313244" : "transparent"
            border.color: panelRoot.sel === 0 ? "#cba6f7" : "transparent"
            border.width: panelRoot.sel === 0 ? 2 : 0
            Text {
                anchors.centerIn: parent
                text: "↔  Reorder apps"
                color: "#89b4fa"
                font.family: panelRoot.bodyFont()
                font.pixelSize: 19
            }
            MouseArea {
                anchors.fill: parent
                onClicked: { panelRoot.sel = 0; panelRoot.reorderRequested() }
            }
        }

        Flickable {
            id: flick
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: reorderRow.bottom
            anchors.bottom: parent.bottom
            anchors.margins: 20
            anchors.topMargin: 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: applist.implicitHeight

            Column {
                id: applist
                width: flick.width
                spacing: 4

                Repeater {
                    model: panelRoot.appsModel
                    delegate: Rectangle {
                        width: applist.width
                        height: 56
                        radius: 10
                        color: panelRoot.sel === index + 1 ? "#313244" : "transparent"
                        border.color: panelRoot.sel === index + 1 ? "#cba6f7" : "transparent"
                        border.width: panelRoot.sel === index + 1 ? 2 : 0

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 140
                            text: model.name
                            color: model.hidden ? "#6c7086" : "#cdd6f4"
                            font.family: panelRoot.bodyFont()
                            font.pixelSize: 18
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            text: model.hidden ? "Hidden" : "Visible"
                            color: model.hidden ? "#f38ba8" : "#a6e3a1"
                            font.family: panelRoot.bodyFont()
                            font.pixelSize: 16
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: { panelRoot.sel = index + 1; panelRoot.toggleAtSel() }
                        }
                    }
                }
            }
        }
    }

    function toggleAtSel() {
        if (panelRoot.sel < 1 || !panelRoot.appsModel) return
        var item = panelRoot.appsModel.get(panelRoot.sel - 1)
        if (item) panelRoot.toggleRequested(item.appId)
    }

    function activate() {
        if (panelRoot.sel === 0) panelRoot.reorderRequested()
        else panelRoot.toggleAtSel()
    }

    function ensureVisible() {
        // reorder row (52) + 8 gap + app rows (56+4)
        var y0 = (panelRoot.sel === 0) ? 0 : 60 + (panelRoot.sel - 1) * 60
        if (y0 < flick.contentY) flick.contentY = y0
        else if (y0 + 56 > flick.contentY + flick.height) flick.contentY = y0 + 56 - flick.height
    }

    Keys.onPressed: {
        if (panelRoot.isBackKey(event.key)) { panelRoot.backRequested(); event.accepted = true; return }
        switch (event.key) {
        case Qt.Key_Up:
            panelRoot.sel = Math.max(0, panelRoot.sel - 1)
            panelRoot.ensureVisible()
            event.accepted = true; break
        case Qt.Key_Down:
            panelRoot.sel = Math.min(panelRoot.appCount, panelRoot.sel + 1)
            panelRoot.ensureVisible()
            event.accepted = true; break
        default:
            if (!event.isAutoRepeat && panelRoot.isActivateKey(event.key)) {
                panelRoot._armedKey = event.key
                event.accepted = true
            }
        }
    }
    Keys.onReleased: {
        if (panelRoot.isActivateKey(event.key)) {
            var armed = (panelRoot._armedKey === event.key)
            panelRoot._armedKey = 0
            if (armed) panelRoot.activate()
            event.accepted = true
        }
    }

    function open() {
        panelRoot.sel = 0
        flick.contentY = 0
        panelRoot._armedKey = 0
        panelRoot.visible = true
        panelRoot.forceActiveFocus()
    }

    function close() {
        panelRoot.visible = false
    }
}
