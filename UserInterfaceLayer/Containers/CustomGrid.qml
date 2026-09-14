import QtQuick 2.12
import QtGraphicalEffects 1.12

// Custom app grid — replaces the HomeAppListComponent / MainRibbon chain

FocusScope {
    id: root

    // ---- Font loaders ----
    FontLoader { id: bodyFontLoader; source: "../../assets/fonts/body.ttf" }
    function bodyFont() { return bodyFontLoader.name || "" }

    property alias mainList: grid

    // Properties set by parent Loader
    property var model: undefined
    property var hiddenAppIds: []
    property var displayNames: ({})
    property var customIcons: ({})
    property var _interfaces: undefined

    property int cellWidth: 210
    property int cellHeight: 210
    property int iconSize: 100
    property var iconTints: ({})

    signal ready()
    signal modelProcessed()
    signal updateShelf()

    anchors.fill: parent
    visible: true
    focus: true

    property bool _filtering: false

    // Tint of the currently highlighted app ("" if none) — consumed by the background shader
    property string selectedTint: ""

    onModelChanged: { if (!root._filtering) root.filterAndLoad() }

    function initialize() {
        console.log("[CustomGrid] initialize")
        if (model) root.filterAndLoad()
    }

    function getId(entry) {
        return entry.id || entry.launchPointId ||
               (entry.entry ? (entry.entry.id || entry.entry.launchPointId) : "")
    }

    // Resolve the accent tint for a model entry (per-app override, else its own iconColor)
    function tintForEntry(entry) {
        if (!entry) return ""
        var e = entry.entry || entry
        var id = e.id || ""
        if (root.iconTints[id]) return root.iconTints[id]
        return typeof e.iconColor === "string" ? e.iconColor : ""
    }

    function syncSelectedTint() {
        if (!root.model || root.model.count === 0) { root.selectedTint = ""; return }
        var idx = Math.max(0, Math.min(grid.currentIndex, root.model.count - 1))
        root.selectedTint = root.tintForEntry(root.model.get(idx))
    }

    function filterAndLoad() {
        if (!model || model.count === 0) return
        console.log("[CustomGrid] filtering", model.count, "items, hidden:", root.hiddenAppIds.length)
        root._filtering = true
        var removed = 0
        for (var i = model.count - 1; i >= 0; i--) {
            var entry = model.get(i)
            if (!entry) continue
            if (root.hiddenAppIds.indexOf(root.getId(entry)) !== -1) {
                console.log("[CustomGrid]  hiding:", root.getId(entry))
                model.remove(i)
                removed++
            }
        }
        console.log("[CustomGrid] done, removed:", removed, "remaining:", model.count)
        root._filtering = false
        root.syncSelectedTint()
        root.ready()
        root.modelProcessed()
        root.updateShelf()
    }

    function updateShelfImplementation() {}

    GridView {
        id: grid
        objectName: "mainList"
        property bool editEnabled: false

        onCurrentIndexChanged: root.syncSelectedTint()

        anchors.fill: parent
        anchors.margins: 12
        focus: true

        cellWidth: root.cellWidth
        cellHeight: root.cellHeight

        flow: GridView.FlowLeftToRight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        clip: true

        model: root.model
        cacheBuffer: Math.max(cellWidth * 4, cellHeight * 4)

        delegate: Item {
            id: cell
            width: grid.cellWidth
            height: grid.cellHeight
            focus: true

            readonly property var entry: modelData

            function launch() {
                if (!entry) return
                console.log("[CustomGrid] launch:", entry.title, "id:", entry.id)
                if (root._interfaces && root._interfaces.application) {
                    root._interfaces.application.launchApp(entry.id, entry.launchPointId, entry.params, "")
                }
            }

            Keys.onReturnPressed: { grid.currentIndex = index; launch() }
            Keys.onEnterPressed: { grid.currentIndex = index; launch() }
            Keys.onPressed: {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Select) {
                    grid.currentIndex = index; launch()
                    event.accepted = true
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                radius: 14
                color: cell.activeFocus ? "#313244" : "#1e1e2e"
                border.color: cell.activeFocus ? "#cba6f7" : "transparent"
                border.width: cell.activeFocus ? 2 : 0
                opacity: cell.activeFocus ? 1 : 0.6

                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Item {
                width: root.iconSize
                height: root.iconSize
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -12

                Image {
                    id: iconImage
                    anchors.fill: parent
                    source: {
                        if (entry) {
                            var e = entry.entry || entry
                            var id = e.id || ""
                            if (root.customIcons[id]) return root.customIcons[id]
                            return e.largeIcon || e.icon || ""
                        }
                        return ""
                    }
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    visible: !cell._iconTint
                }

                ColorOverlay {
                    anchors.fill: iconImage
                    source: iconImage
                    color: cell._iconTint || "transparent"
                    visible: !!cell._iconTint
                }
            }

            property string _iconTint: root.tintForEntry(entry)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                width: root.cellWidth - 24
                text: {
                    if (!entry) return ""
                    return root.displayNames[entry.id] || entry.title || ""
                }
                color: "#cdd6f4"
                font.pixelSize: 14
                font.family: bodyFont()
                font.weight: Font.Normal
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    grid.currentIndex = index
                    grid.forceActiveFocus()
                    cell.launch()
                }
                onPressAndHold: {
                    if (!entry) return
                    if (root._interfaces && root._interfaces.application) {
                        var id = (entry.entry || entry).id || ""
                        root._interfaces.application.createToast({
                            "iconUrl": "",
                            "message": id,
                            "noaction": true
                        })
                    }
                }
            }
        }
    }
}
