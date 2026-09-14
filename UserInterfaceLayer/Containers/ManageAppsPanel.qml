import QtQuick 2.12

// "Manage all apps" panel: lists every launch point (including hidden ones)
// so hidden apps can always be restored. D-pad: Up/Down moves, OK toggles
// hidden, Back/Escape closes.

FocusScope {
    id: panelRoot

    property var appsModel: null       // ListModel { appId, name, hidden }

    signal toggleRequested(string appId)
    signal closed()
    signal backRequested()

    FontLoader { id: bodyFontLoader; source: "../../assets/fonts/body.ttf" }
    function bodyFont() { return bodyFontLoader.name || "" }

    anchors.fill: parent
    visible: false
    focus: true
    z: 110

    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.6 }

    Rectangle {
        anchors.centerIn: parent
        width: 720
        height: parent.height * 0.8
        radius: 18
        color: "#1e1e2e"
        border.color: "#45475a"
        border.width: 2

        Text {
            id: title
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 20
            text: "Manage all apps"
            color: "#cdd6f4"
            font.family: panelRoot.bodyFont()
            font.pixelSize: 24
            font.weight: Font.Bold
        }

        ListView {
            id: list
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: title.bottom
            anchors.bottom: parent.bottom
            anchors.margins: 20
            anchors.topMargin: 16
            clip: true
            focus: true
            model: panelRoot.appsModel
            currentIndex: 0
            keyNavigationWraps: true
            boundsBehavior: Flickable.StopAtBounds

            property int _armedKey: 0
            Keys.onPressed: {
                if (panelRoot.isBackKey(event.key)) { panelRoot.backRequested(); event.accepted = true; return }
                if (!event.isAutoRepeat && panelRoot.isActivateKey(event.key)) {
                    list._armedKey = event.key
                    event.accepted = true
                }
            }
            Keys.onReleased: {
                if (panelRoot.isActivateKey(event.key)) {
                    var armed = (list._armedKey === event.key)
                    list._armedKey = 0
                    if (armed) panelRoot.toggleCurrent()
                    event.accepted = true
                }
            }

            delegate: Rectangle {
                width: list.width
                height: 56
                radius: 10
                color: ListView.isCurrentItem ? "#313244" : "transparent"
                border.color: ListView.isCurrentItem ? "#cba6f7" : "transparent"
                border.width: ListView.isCurrentItem ? 2 : 0

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
            }
        }
    }

    function isActivateKey(key) {
        return key === Qt.Key_Return || key === Qt.Key_Enter ||
               key === Qt.Key_Space || key === Qt.Key_Select
    }
    function isBackKey(key) {
        // 18874371 == 0x01200003 is the webOS remote Back key (LG calls it ir_key_back)
        return key === Qt.Key_Back || key === Qt.Key_Escape ||
               key === Qt.Key_Cancel || key === 18874371
    }

    function toggleCurrent() {
        if (!panelRoot.appsModel) return
        var item = panelRoot.appsModel.get(list.currentIndex)
        if (item) panelRoot.toggleRequested(item.appId)
    }

    function open() {
        panelRoot.visible = true
        list.currentIndex = 0
        panelRoot.forceActiveFocus()
        list.forceActiveFocus()
    }

    function close() {
        panelRoot.visible = false
    }
}
