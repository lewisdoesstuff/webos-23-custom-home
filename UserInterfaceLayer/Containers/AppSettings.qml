import QtQuick 2.12
import "config.js" as Config

// Global, on-device settings (clock, weather, background shader, app handling).
// Persisted in DB8 (mode "customSettings"); config.js provides the defaults.
// (Item, not QtObject, because the retry Timer needs a default property.)

Item {
    id: s
    visible: false

    property var interfaces: undefined
    property bool ready: false
    property int _attempts: 0
    property bool _loading: false
    property bool _docExists: false

    // Clock
    property bool clock24h: true
    property bool showAmPm: false
    // Weather
    property string weatherUnit: "C"
    // Background shader (seeded from config.js)
    property bool constellationEnabled: Config.constellationEnabled
    property real constellationScale: Config.constellation.scale
    property real constellationLineWidth: Config.constellation.lineWidth
    property real constellationSpeed: Config.constellation.speed
    property real constellationAlpha: Config.constellation.alpha
    property bool constellationTintFromApp: Config.constellation.tintFromApp
    // Apps
    property bool autoHideNewApps: false
    property var knownApps: []
    property var appOrder: []

    // Bump when code defaults change; stored docs below this rev get the
    // re-tuned shader defaults applied (other user values are preserved).
    readonly property int defaultsRev: 2

    signal loaded()

    // Retry until the DB bridge is available; until then the defaults drive the UI.
    Timer {
        interval: 1000
        repeat: true
        running: !s.ready && s._attempts < 12
        onTriggered: s.load()
    }

    function appInterface() {
        return (interfaces && interfaces.application) ? interfaces.application : null
    }

    function load() {
        if (s.ready || s._loading) return
        var app = s.appInterface()
        if (!app || typeof app.getPreferences !== "function") {
            s._attempts++
            if (s._attempts >= 12) { s.ready = true; s.loaded() }
            return
        }
        s._loading = true
        s._attempts++
        app.getPreferences(function (resp) {
            s._loading = false
            var prefs = null
            if (resp && resp.results) {
                for (var i = 0; i < resp.results.length; i++) {
                    var r = resp.results[i]
                    if (r && r.mode === "customSettings") { prefs = r.preferences || {}; s._docExists = true }
                }
            }
            if (prefs) s.apply(prefs)
            s.ready = true
            s.loaded()
            // Persist migrated defaults (apply() pulled code values into any stale doc)
            if (prefs && (prefs.defaultsRev || 0) < s.defaultsRev) s.save()
        })
    }

    function apply(prefs) {
        if (prefs.clock24h !== undefined) s.clock24h = prefs.clock24h
        if (prefs.showAmPm !== undefined) s.showAmPm = prefs.showAmPm
        if (prefs.weatherUnit !== undefined) s.weatherUnit = prefs.weatherUnit
        if (prefs.constellationEnabled !== undefined) s.constellationEnabled = prefs.constellationEnabled
        if (prefs.constellationScale !== undefined) s.constellationScale = prefs.constellationScale
        if (prefs.constellationLineWidth !== undefined) s.constellationLineWidth = prefs.constellationLineWidth
        if (prefs.constellationSpeed !== undefined) s.constellationSpeed = prefs.constellationSpeed
        if (prefs.constellationAlpha !== undefined) s.constellationAlpha = prefs.constellationAlpha
        if (prefs.constellationTintFromApp !== undefined) s.constellationTintFromApp = prefs.constellationTintFromApp
        if (prefs.autoHideNewApps !== undefined) s.autoHideNewApps = prefs.autoHideNewApps
        if (prefs.knownApps !== undefined) s.knownApps = prefs.knownApps
        if (prefs.appOrder !== undefined) s.appOrder = prefs.appOrder
        if ((prefs.defaultsRev || 0) < s.defaultsRev) {
            s.constellationScale = Config.constellation.scale
            s.constellationLineWidth = Config.constellation.lineWidth
            s.constellationSpeed = Config.constellation.speed
            s.constellationAlpha = Config.constellation.alpha
        }
    }

    function snapshot() {
        return {
            defaultsRev: s.defaultsRev,
            clock24h: s.clock24h,
            showAmPm: s.showAmPm,
            weatherUnit: s.weatherUnit,
            constellationEnabled: s.constellationEnabled,
            constellationScale: s.constellationScale,
            constellationLineWidth: s.constellationLineWidth,
            constellationSpeed: s.constellationSpeed,
            constellationAlpha: s.constellationAlpha,
            constellationTintFromApp: s.constellationTintFromApp,
            autoHideNewApps: s.autoHideNewApps,
            knownApps: s.knownApps,
            appOrder: s.appOrder
        }
    }

    function save() {
        var app = s.appInterface()
        if (!app) return
        var doc = { mode: "customSettings", preferences: s.snapshot() }
        if (s._docExists && typeof app.updatePreference === "function") {
            app.updatePreference(doc)
        } else if (typeof app.addPreference === "function") {
            app.addPreference(doc)
            s._docExists = true
        }
    }
}
