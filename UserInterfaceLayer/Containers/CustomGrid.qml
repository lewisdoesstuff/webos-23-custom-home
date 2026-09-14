import QtQuick 2.12
import QtGraphicalEffects 1.12

// Custom app grid — replaces the HomeAppListComponent / MainRibbon chain.
//
// Per-app overrides (hidden / name / tint / icon) are stored in DB8
// (com.webos.app.home.preferences:1, mode "customOverrides") and layered over
// the config.js defaults, so they can be edited on-device.

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
    property var iconTints: ({})
    property var tintChoices: []
    property var iconChoices: []
    property var _interfaces: undefined

    property int cellWidth: 210
    property int cellHeight: 210
    property int iconSize: 100

    signal ready()
    signal modelProcessed()
    signal updateShelf()

    anchors.fill: parent
    visible: true
    focus: true

    // Tint of the currently highlighted app ("" if none) — consumed by the background shader
    property string selectedTint: ""

    // Raw launch points (untouched) + effective overrides
    property var allEntries: []
    property var overrides: ({})
    property bool _docExists: false
    property int _menuReturnRow: 0

    ListModel { id: displayModel }
    ListModel { id: manageModel }

    readonly property int visibleCount: displayModel.count
    readonly property int totalCount: manageModel.count

    onModelChanged: root.capture()

    function initialize() {
        console.log("[CustomGrid] initialize")
        root.capture()
    }

    // ---- entry helpers ----
    function rawEntry(raw) { return (raw && raw.entry) ? raw.entry : raw }
    function appIdOf(raw) {
        var e = root.rawEntry(raw)
        return e ? (e.id || e.launchPointId || "") : ""
    }
    function lpIdOf(raw) {
        var e = root.rawEntry(raw)
        return e ? (e.launchPointId || e.id || "") : ""
    }

    function eff(raw) {
        var e = root.rawEntry(raw)
        var id = root.appIdOf(raw)
        var ov = root.overrides[id] || {}
        var hidden = (typeof ov.hidden === "boolean") ? ov.hidden
                                                     : (root.hiddenAppIds.indexOf(id) !== -1)
        var name = (ov.name !== undefined && ov.name !== "") ? ov.name
                                                             : (root.displayNames[id] || (e ? e.title : "") || "")
        var tint = (ov.tint !== undefined && ov.tint !== "") ? ov.tint
                     : (root.iconTints[id] || (e && typeof e.iconColor === "string" ? e.iconColor : ""))
        var icon = (ov.icon !== undefined && ov.icon !== "") ? ov.icon
                     : (root.customIcons[id] || (e ? (e.largeIcon || e.icon) : "") || "")
        return { appId: id, hidden: hidden, name: name, tint: tint, icon: icon }
    }

    function findRaw(appId) {
        for (var i = 0; i < root.allEntries.length; i++)
            if (root.appIdOf(root.allEntries[i]) === appId) return root.allEntries[i]
        return null
    }

    // ---- capture source model (non-destructive) ----
    function capture() {
        if (!root.model || root.model.count === 0) return
        var arr = []
        for (var i = 0; i < root.model.count; i++) {
            var e = root.model.get(i)
            if (e) arr.push(e)
        }
        root.allEntries = arr
        root.rebuild()          // render immediately with config defaults
        root.loadOverrides()    // then layer on any DB8 overrides
    }

    // ---- DB8 overrides ----
    function appInterface() {
        return (root._interfaces && root._interfaces.application) ? root._interfaces.application : null
    }

    function loadOverrides() {
        var app = root.appInterface()
        if (!app || typeof app.getPreferences !== "function") { root.rebuild(); return }
        app.getPreferences(function(resp) {
            var map = {}
            var found = false
            if (resp && resp.results) {
                for (var i = 0; i < resp.results.length; i++) {
                    var r = resp.results[i]
                    if (r && r.mode === "customOverrides" && r.preferences) {
                        map = r.preferences
                        found = true
                    }
                }
            }
            root.overrides = map
            root._docExists = found
            root.rebuild()
        })
    }

    function persist() {
        var app = root.appInterface()
        if (!app) return
        var doc = { mode: "customOverrides", preferences: root.overrides }
        if (root._docExists && typeof app.updatePreference === "function") {
            app.updatePreference(doc)
        } else if (typeof app.addPreference === "function") {
            app.addPreference(doc)
            root._docExists = true
        }
    }

    function setOverride(appId, key, value) {
        if (!appId) return
        var ov = root.overrides[appId]
        if (!ov) { ov = {}; root.overrides[appId] = ov }
        if (value === "" || value === undefined || value === null) delete ov[key]
        else ov[key] = value
        if (Object.keys(ov).length === 0) delete root.overrides[appId]
        root.overrides = root.overrides   // reassign so bindings refresh
        root.persist()
    }

    // ---- rebuild models ----
    function rebuild() {
        root.rebuildDisplay()
        root.rebuildManage()
        root.syncSelectedTint()
        root.ready()
        root.modelProcessed()
        root.updateShelf()
    }

    function rebuildDisplay() {
        displayModel.clear()
        for (var i = 0; i < root.allEntries.length; i++) {
            var raw = root.allEntries[i]
            var e = root.eff(raw)
            if (e.appId === "" || e.hidden) continue
            displayModel.append({
                appId: e.appId,
                launchPointId: root.lpIdOf(raw),
                name: e.name,
                icon: e.icon,
                tint: e.tint,
                params: root.rawEntry(raw).params
            })
        }
    }

    function rebuildManage() {
        manageModel.clear()
        for (var i = 0; i < root.allEntries.length; i++) {
            var raw = root.allEntries[i]
            var e = root.eff(raw)
            if (e.appId === "") continue
            manageModel.append({
                appId: e.appId,
                name: (e.name !== "" ? e.name : e.appId),
                hidden: e.hidden
            })
        }
    }

    function syncSelectedTint() {
        if (displayModel.count === 0) { root.selectedTint = ""; return }
        var idx = Math.max(0, Math.min(grid.currentIndex, displayModel.count - 1))
        root.selectedTint = displayModel.get(idx).tint
    }

    // ---- actions ----
    function toggleHidden(appId) {
        var raw = root.findRaw(appId)
        if (!raw) return
        var wasHidden = root.eff(raw).hidden
        root.setOverride(appId, "hidden", !wasHidden)
        root.updateManageHidden(appId, !wasHidden)
        root.rebuildDisplay()
        root.syncSelectedTint()
    }

    function updateManageHidden(appId, hidden) {
        for (var i = 0; i < manageModel.count; i++) {
            if (manageModel.get(i).appId === appId) { manageModel.setProperty(i, "hidden", hidden); return }
        }
    }

    function menuEntryFor(appId) {
        var e = root.eff(root.findRaw(appId))
        return { appId: e.appId, name: e.name, hidden: e.hidden, tint: e.tint, icon: e.icon }
    }

    function openMenu(appId, keyHeld) {
        menu.entry = root.menuEntryFor(appId)
        menu.open(keyHeld === true)
        grid.enabled = false
    }

    function closeMenu() {
        menu.close()
        grid.enabled = true
        grid.forceActiveFocus()
    }

    function openManage() {
        root._menuReturnRow = menu.row
        menu.close()
        panel.open()
        grid.enabled = false
    }

    function closeManage() {
        panel.close()
        grid.enabled = true
        grid.forceActiveFocus()
    }

    // Long-press menu overlay
    AppMenu {
        id: menu
        anchors.fill: parent
        tintChoices: root.tintChoices
        iconChoices: root.iconChoices

        onHideToggle: { root.toggleHidden(menu.entry.appId); root.closeMenu() }
        onRenameRequested: root.renameApp(menu.entry.appId)
        onTintPicked: {
            root.setOverride(menu.entry.appId, "tint", tint)
            menu.entry.tint = tint
            root.rebuildDisplay()
        }
        onIconPicked: {
            root.setOverride(menu.entry.appId, "icon", path)
            menu.entry.icon = path
            root.rebuildDisplay()
        }
        onManageRequested: root.openManage()
        onResetRequested: {
            delete root.overrides[menu.entry.appId]
            root.overrides = root.overrides
            root.persist()
            root.rebuild()
            root.closeMenu()
        }
        onClosed: root.closeMenu()
    }

    // Manage-all panel
    ManageAppsPanel {
        id: panel
        anchors.fill: parent
        appsModel: manageModel
        onToggleRequested: root.toggleHidden(appId)
        onClosed: root.closeManage()
        onBackRequested: {
            panel.close()
            menu.open(false, root._menuReturnRow)
            grid.enabled = false
        }
    }

    // Rename keyboard
    RenameKeyboard {
        id: renameKb
        anchors.fill: parent
        onAccepted: {
            root.setOverride(renameKb.appId, "name", text)
            root.rebuildDisplay()
            renameKb.close()
            root.closeMenu()
        }
        onCancelled: {
            renameKb.close()
            root.closeMenu()
        }
    }

    // Rename via the built-in on-screen keyboard
    function renameApp(appId) {
        var current = root.menuEntryFor(appId).name
        menu.close()
        renameKb.appId = appId
        renameKb.open(current)
        grid.enabled = false
    }

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

        model: displayModel
        cacheBuffer: Math.max(cellWidth * 4, cellHeight * 4)

        delegate: Item {
            id: cell
            width: grid.cellWidth
            height: grid.cellHeight

            property bool longPressed: false

            function launch() {
                if (root._interfaces && root._interfaces.application) {
                    root._interfaces.application.launchApp(model.appId, model.launchPointId, model.params, "")
                }
            }
            function isActivate(key) {
                return key === Qt.Key_Return || key === Qt.Key_Enter ||
                       key === Qt.Key_Space || key === Qt.Key_Select
            }

            Timer {
                id: pressTimer
                interval: 650
                repeat: false
                onTriggered: {
                    cell.longPressed = true
                    grid.currentIndex = index
                    root.openMenu(model.appId, true)
                }
            }

            Keys.onPressed: {
                if (cell.isActivate(event.key)) {
                    if (!event.isAutoRepeat) { cell.longPressed = false; pressTimer.start() }
                    event.accepted = true
                }
            }
            Keys.onReleased: {
                if (cell.isActivate(event.key)) {
                    pressTimer.stop()
                    if (!cell.longPressed) {
                        grid.currentIndex = index
                        cell.launch()
                    }
                    cell.longPressed = false
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
                    source: model.icon || ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    visible: !model.tint
                }

                ColorOverlay {
                    anchors.fill: iconImage
                    source: iconImage
                    color: model.tint || "transparent"
                    visible: !!model.tint
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                width: root.cellWidth - 24
                text: model.name || ""
                color: "#cdd6f4"
                font.pixelSize: 14
                font.family: root.bodyFont()
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
                    grid.currentIndex = index
                    root.openMenu(model.appId, false)
                }
            }
        }
    }
}
