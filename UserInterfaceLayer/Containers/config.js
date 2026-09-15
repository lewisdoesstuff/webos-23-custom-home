.pragma library

// App IDs to hide from the grid
var hiddenAppIds = [
    "com.webos.app.lgchannels",
    "amazon.alexa.view",
    "com.webos.app.homeconnect",
    "com.webos.app.sportsteamsettings",
    "com.webos.app.mediadiscovery",
    "com.webos.app.camera",
    "com.webos.app.lifeonscreen",
    "com.pirate.refresh",
    "org.webosbrew.custom-screensaver"
]

// Custom display names (app ID -> display name)
var displayNames = {
    "spotify-beehive": "Spotify",
    "youtube.leanback.v4": "YouTube",
}

// Custom icons (app ID -> path relative to CustomGrid.qml)
var customIcons = {
    "spotify-beehive": "../../assets/icons/spotify.png",
    "youtube.leanback.v4": "../../assets/icons/youtube.png",
    "cdp-30": "../../assets/icons/plex.png",
    "com.collegehumor.chdropout": "../../assets/icons/dropout.png",
    "tv.twitch.tv.starshot.lg": "../../assets/icons/twitch.png",
    "org.webosbrew.hbchannel": "../../assets/icons/homebrew.png",
    "com.limelight.webos": "../../assets/icons/moonlight.png",
    "com.webos.app.browser": "../../assets/icons/browser.png"
}

// Icon tint colors (app ID -> color)
// Uses the Catppuccin Mocha palette: https://catppuccin.com/palette
var iconTints = {
    "com.webos.app.discovery": "#89b4fa",  // Blue
    "spotify-beehive":         "#a6e3a1",  // Green
    "youtube.leanback.v4":     "#f38ba8",  // Red
    "cdp-30":                  "#f9e2af",  // Yellow
    "com.collegehumor.chdropout": "#f9e2af",  // Yellow
    "tv.twitch.tv.starshot.lg":   "#cba6f7",  // Mauve
    "org.webosbrew.hbchannel":    "#fab387",  // Peach
    "com.limelight.webos":        "#74c7ec",  // Sapphire
    "com.webos.app.browser":      "#89dceb",  // Sky
}

// ---- Background constellation (node/edge) effect ----

// Master on/off switch for the animated background
var constellationEnabled = true

var constellation = {
    scale: 4.5,        // grid density — higher = more points/lines
    lineWidth: 0.013,  // edge thickness
    speed: 0.4,        // animation speed
    alpha: 0.6,        // overall opacity
    nodeColor: "#cba6f7",
    edgeColor: "#89b4fa",
    tintFromApp: true  // tint the nodes/edges with the highlighted app's colour
}

// ---- In-app editor choices ----

// Tint swatches offered in the long-press menu ("" = app/config default)
var tintChoices = [
    "",          // Default
    "#89b4fa",   // Blue
    "#a6e3a1",   // Green
    "#f38ba8",   // Red
    "#f9e2af",   // Yellow
    "#cba6f7",   // Mauve
    "#fab387",   // Peach
    "#74c7ec",   // Sapphire
    "#89dceb",   // Sky
    "#94e2d5"    // Teal
]

// Icons offered in the long-press menu (path is relative to CustomGrid.qml)
var iconChoices = [
    { name: "App default", path: "" },
    { name: "Browser",     path: "../../assets/icons/browser.png" },
    { name: "Dropout",     path: "../../assets/icons/dropout.png" },
    { name: "Homebrew",    path: "../../assets/icons/homebrew.png" },
    { name: "Moonlight",   path: "../../assets/icons/moonlight.png" },
    { name: "Plex",        path: "../../assets/icons/plex.png" },
    { name: "Spotify",     path: "../../assets/icons/spotify.png" },
    { name: "Twitch",      path: "../../assets/icons/twitch.png" },
    { name: "YouTube",     path: "../../assets/icons/youtube.png" }
]
