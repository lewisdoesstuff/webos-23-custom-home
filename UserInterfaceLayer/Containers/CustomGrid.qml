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
    property var appSettings: null

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

    // Reorder mode: one visible app is "held" and the arrows move it
    property bool reorderMode: false
    property string reorderAppId: ""

    function isBackKey(key) {
        return key === Qt.Key_Back || key === Qt.Key_Escape ||
               key === Qt.Key_Cancel || key === 18874371
    }

    ListModel { id: displayModel }
    ListModel { id: manageModel }

    readonly property int visibleCount: displayModel.count
    readonly property int totalCount: manageModel.count

    onModelChanged: root.capture()

    // Recapture once the app settings (ordering, auto-hide baseline) are ready
    Connections {
        target: root.appSettings
        ignoreUnknownSignals: true
        onLoaded: root.capture()
    }

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
                     : (root.hiddenAppIds.indexOf(id) !== -1 || root._isAutoHidden(id))
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

    // Apps installed after the baseline are hidden when auto-hide is on.
    function _isAutoHidden(id) {
        if (!root.appSettings || !root.appSettings.autoHideNewApps) return false
        var known = root.appSettings.knownApps || []
        if (known.length === 0) return false   // baseline not seeded yet
        return known.indexOf(id) === -1
    }

    function _syncKnownApps() {
        if (!root.appSettings) return
        var known = root.appSettings.knownApps ? root.appSettings.knownApps.slice() : []
        var empty = known.length === 0
        var changed = false
        for (var i = 0; i < root.allEntries.length; i++) {
            var id = root.appIdOf(root.allEntries[i])
            if (id === "") continue
            if (known.indexOf(id) === -1 && (empty || !root.appSettings.autoHideNewApps)) {
                known.push(id)
                changed = true
            }
        }
        if (changed) { root.appSettings.knownApps = known; root.appSettings.save() }
    }

    // ---- capture source model (non-destructive) ----
    function capture() {
        if (!root.model || root.model.count === 0) return
        var arr = []
        for (var i = 0; i < root.model.count; i++) {
            var e = root.model.get(i)
            if (e) arr.push(e)
        }
        // Apply custom ordering (apps not listed keep their relative position at the end)
        if (root.appSettings && root.appSettings.appOrder && root.appSettings.appOrder.length) {
            var order = root.appSettings.appOrder
            arr.sort(function (a, b) {
                var ia = order.indexOf(root.appIdOf(a)); if (ia < 0) ia = 9999
                var ib = order.indexOf(root.appIdOf(b)); if (ib < 0) ib = 9999
                return ia - ib
            })
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

    // Debounced exact-save: coalesces rapid edits (e.g. tint cycling) so only
    // the final state hits DB8. Restartable — each persist() restarts the clock.
    Timer {
        id: persistDebounce
        interval: 400
        repeat: false
        onTriggered: root._persistNow()
    }

    function persist() {
        persistDebounce.restart()
    }

    // Exact replace (del by mode, then put) chained via the services dispatch
    // object with full DB8 args, bypassing the stock wrappers (which use
    // merge and therefore can never delete keys — deleted overrides would
    // resurrect on next load). First save goes through the same path: del
    // simply matches nothing, then put creates the doc.
    function _persistNow() {
        var app = root.appInterface()
        if (!app) return
        var kind = (app.dbName && app.dbName !== "") ? app.dbName : "com.webos.app.home.preferences:1"
        if (app.services && typeof app.services.removePreference === "function"
                && typeof app.services.addPreference === "function") {
            var delArgs = {
                query: {
                    from: kind,
                    where: [{ prop: "mode", op: "=", val: "customOverrides" }]
                }
            }
            var putArgs = {
                objects: [{ _kind: kind, mode: "customOverrides", preferences: root.overrides }]
            }
            try {
                app.services.removePreference(delArgs, function () {
                    app.services.addPreference(putArgs, function () {
                        root._docExists = true
                    })
                })
            } catch (e) {
                console.log("[CustomGrid] exact save failed, keeping in-memory state: " + e)
            }
            return
        }
        // Fallback for hosts without the services dispatch (e.g. minimal
        // mocks): stock wrappers use merge semantics and may leave zombies.
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
        root._syncKnownApps()
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

    function closeAllOverlays() {
        menu.close()
        panel.close()
        settingsScreen.close()
        renameKb.close()
    }

    function openMenu(appId, keyHeld) {
        root.closeAllOverlays()
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
        root.closeAllOverlays()
        panel.open()
        grid.enabled = false
    }

    function enterReorder() {
        if (displayModel.count === 0) return
        root.closeAllOverlays()
        var idx = Math.max(0, Math.min(grid.currentIndex, displayModel.count - 1))
        root.reorderAppId = displayModel.get(idx).appId
        root.reorderMode = true
        grid.currentIndex = idx
        grid.enabled = true
        grid.forceActiveFocus()
    }

    function exitReorder() {
        root.reorderMode = false
        root.reorderAppId = ""
        grid.forceActiveFocus()
    }

    function reorderName() {
        for (var i = 0; i < displayModel.count; i++)
            if (displayModel.get(i).appId === root.reorderAppId) return displayModel.get(i).name
        return ""
    }

    // Move the held app to a visible slot, keeping hidden apps in place, then persist.
    function applyVisibleMove(id, toVisIndex) {
        var vis = []
        for (var i = 0; i < displayModel.count; i++) vis.push(displayModel.get(i).appId)
        var from = vis.indexOf(id)
        if (from < 0) return
        vis.splice(from, 1)
        toVisIndex = Math.max(0, Math.min(vis.length, toVisIndex))
        vis.splice(toVisIndex, 0, id)

        var hidden = {}
        for (var k = 0; k < root.allEntries.length; k++) {
            var hid = root.appIdOf(root.allEntries[k])
            if (root.eff(root.allEntries[k]).hidden) hidden[hid] = true
        }

        var oldFull = []
        for (var m = 0; m < root.allEntries.length; m++) oldFull.push(root.appIdOf(root.allEntries[m]))
        var vi = 0
        var newFull = []
        for (var n = 0; n < oldFull.length; n++) {
            if (hidden[oldFull[n]]) newFull.push(oldFull[n])
            else newFull.push(vis[vi++])
        }

        var byId = {}
        for (var q = 0; q < root.allEntries.length; q++) byId[root.appIdOf(root.allEntries[q])] = root.allEntries[q]
        var reordered = []
        for (var r = 0; r < newFull.length; r++) {
            if (byId[newFull[r]]) reordered.push(byId[newFull[r]])
        }
        root.allEntries = reordered

        if (root.appSettings) {
            root.appSettings.appOrder = newFull.slice()
            root.appSettings.save()
        }
        // Animate the visible move; refresh the manage list only (it is closed in reorder mode)
        displayModel.move(from, toVisIndex, 1)
        root.rebuildManage()
        grid.currentIndex = toVisIndex
        root.syncSelectedTint()
    }

    function moveHeld(dx, dy) {
        if (!root.reorderMode || root.reorderAppId === "" || displayModel.count === 0) return
        var cols = Math.max(1, Math.floor(grid.width / root.cellWidth))
        var cur = grid.currentIndex
        var target = cur + dx + dy * cols
        target = Math.max(0, Math.min(displayModel.count - 1, target))
        if (target === cur) return
        root.applyVisibleMove(root.reorderAppId, target)
    }

    function openSettings() {
        root.closeAllOverlays()
        root._menuReturnRow = menu.row
        menu.close()
        settingsScreen.open(false)
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
        onSettingsRequested: root.openSettings()
        onResetRequested: {
            delete root.overrides[menu.entry.appId]
            root.overrides = root.overrides
            root.persist()
            root.rebuild()
            root.closeMenu()
        }
        onClosed: root.closeMenu()
    }

    // Settings screen
    SettingsScreen {
        id: settingsScreen
        anchors.fill: parent
        appSettings: root.appSettings
        onManageRequested: { settingsScreen.close(); root.openManage() }
        onBackRequested: {
            settingsScreen.close()
            menu.open(false, root._menuReturnRow)
            grid.enabled = false
        }
        onTextRequested: {
            renameKb.purpose = "greeter"
            renameKb.title = "Greeter name"
            renameKb.appId = ""
            renameKb.open(initial)
            grid.enabled = false
        }
    }

    // Manage-all panel
    ManageAppsPanel {
        id: panel
        anchors.fill: parent
        appsModel: manageModel
        onToggleRequested: root.toggleHidden(appId)
        onReorderRequested: root.enterReorder()
        onClosed: root.closeManage()
        onBackRequested: {
            panel.close()
            settingsScreen.open(false)
            grid.enabled = false
        }
    }

    // Reorder-mode hint bar
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        height: 48
        radius: 12
        color: "#1e1e2e"
        border.color: "#cba6f7"
        border.width: 2
        visible: root.reorderMode
        z: 120
        Text {
            anchors.centerIn: parent
            text: "Moving " + root.reorderName() + "  ·  arrows move  ·  OK drops  ·  Back cancels"
            color: "#cdd6f4"
            font.family: root.bodyFont()
            font.pixelSize: 17
        }
    }

    // Rename keyboard
    RenameKeyboard {
        id: renameKb
        anchors.fill: parent
        onAccepted: {
            if (renameKb.purpose === "greeter") {
                if (root.appSettings) {
                    root.appSettings.greeterName = text
                    root.appSettings.save()
                }
                renameKb.close()
                settingsScreen.open(false)
                grid.enabled = false
            } else {
                root.setOverride(renameKb.appId, "name", text)
                root.rebuildDisplay()
                renameKb.close()
                root.closeMenu()
            }
        }
        onCancelled: {
            if (renameKb.purpose === "greeter") {
                renameKb.close()
                settingsScreen.open(false)
                grid.enabled = false
            } else {
                renameKb.close()
                root.closeMenu()
            }
        }
    }

    // Rename via the built-in on-screen keyboard
    function renameApp(appId) {
        var current = root.menuEntryFor(appId).name
        root.closeAllOverlays()
        renameKb.purpose = "app"
        renameKb.title = "Rename app"
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

        populate: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 }
        }
        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 150 }
        }
        move: Transition {
            NumberAnimation { properties: "x,y"; duration: 260; easing.type: Easing.OutCubic }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: 260; easing.type: Easing.OutCubic }
        }

        delegate: Item {
            id: cell
            width: grid.cellWidth
            height: grid.cellHeight
            transformOrigin: Item.Center
            scale: (cell.activeFocus || tileBg.held) ? 1.04 : 1.0

            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

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
                if (root.reorderMode) {
                    switch (event.key) {
                    case Qt.Key_Up: root.moveHeld(0, -1); event.accepted = true; break
                    case Qt.Key_Down: root.moveHeld(0, 1); event.accepted = true; break
                    case Qt.Key_Left: root.moveHeld(-1, 0); event.accepted = true; break
                    case Qt.Key_Right: root.moveHeld(1, 0); event.accepted = true; break
                    default:
                        if (root.isBackKey(event.key) || cell.isActivate(event.key)) event.accepted = true
                    }
                    return
                }
                if (cell.isActivate(event.key)) {
                    if (!event.isAutoRepeat) { cell.longPressed = false; pressTimer.start() }
                    event.accepted = true
                }
            }
            Keys.onReleased: {
                if (root.reorderMode) {
                    if (cell.isActivate(event.key)) {
                        root.exitReorder()
                        event.accepted = true
                    } else if (root.isBackKey(event.key)) {
                        root.exitReorder()
                        event.accepted = true
                    }
                    return
                }
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
                id: tileBg
                anchors.fill: parent
                anchors.margins: 6
                radius: 14
                property bool held: root.reorderMode && model.appId === root.reorderAppId
                color: (cell.activeFocus || held) ? "#313244" : "#1e1e2e"
                border.color: held ? "#f9e2af" : (cell.activeFocus ? (model.tint || "#cba6f7") : "transparent")
                border.width: (cell.activeFocus || held) ? 2 : 0
                opacity: (cell.activeFocus || held) ? 1 : 0.6

                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            DropShadow {
                anchors.fill: tileBg
                source: tileBg
                radius: 18
                samples: 19
                color: model.tint || "#cba6f7"
                transparentBorder: true
                opacity: (cell.activeFocus || tileBg.held) ? 0.5 : 0.0
                visible: opacity > 0.01

                Behavior on opacity { NumberAnimation { duration: 180 } }
            }

            Item {
                width: root.iconSize
                height: root.iconSize
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -12
                layer.enabled: true
                layer.smooth: true
                layer.textureSize: Qt.size(root.iconSize * 2, root.iconSize * 2)

                Image {
                    id: iconImage
                    anchors.fill: parent
                    source: model.icon || ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    smooth: true
                    mipmap: true
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
                    if (root.reorderMode) { root.exitReorder(); return }
                    grid.currentIndex = index
                    grid.forceActiveFocus()
                    cell.launch()
                }
                onPressAndHold: {
                    if (root.reorderMode) return
                    grid.currentIndex = index
                    root.openMenu(model.appId, false)
                }
            }
        }
    }
}
