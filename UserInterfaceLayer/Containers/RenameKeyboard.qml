import QtQuick 2.12
import QtQuick.Window 2.12

// Rename overlay: a focused TextInput, so the platform's native on-screen
// keyboard is presented automatically (same pattern LG's dvrpopup uses).
// Done/Enter saves, Back cancels.
//
// This component is hosted inside the app-grid area (lower half of the screen),
// so the panel is positioned in window coordinates to sit above the keyboard.

FocusScope {
    id: kb

    property string appId: ""
    property string text: ""
    property string title: "Rename app"
    property string purpose: "app"
    property int maxLength: 24

    signal accepted(string text)
    signal cancelled()

    FontLoader { id: bodyFontLoader; source: "../../assets/fonts/body.ttf" }
    function bodyFont() { return bodyFontLoader.name || "" }

    function isBack(key) {
        // NB: not Backspace — that must delete characters in the TextInput
        return key === Qt.Key_Back || key === Qt.Key_Escape ||
               key === Qt.Key_Cancel || key === 18874371
    }

    // Offset from this item to the top-left of the window
    readonly property real _offY: kb.mapToItem(null, 0, 0).y

    anchors.fill: parent
    visible: false
    focus: true
    z: 120

    Rectangle {
        // dim the whole window, not just the grid area
        x: 0
        y: -kb._offY
        width: kb.width
        height: Window.window ? Window.window.height : kb.height
        color: "#000000"
        opacity: 0.7
    }

    Rectangle {
        id: panel
        x: (kb.width - width) / 2
        y: -kb._offY + 60
        width: 780
        height: content.implicitHeight + 40
        radius: 18
        color: "#1e1e2e"
        border.color: "#45475a"
        border.width: 2

        Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 20
            spacing: 12

            Text {
                width: parent.width
                text: kb.title
                color: "#a6adc8"
                font.family: kb.bodyFont()
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                width: parent.width
                height: 64
                radius: 10
                color: "#11111b"
                border.color: input.activeFocus ? "#cba6f7" : "#45475a"
                border.width: input.activeFocus ? 2 : 1

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.margins: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: "#cdd6f4"
                    font.family: kb.bodyFont()
                    font.pixelSize: 26
                    focus: true
                    selectByMouse: false
                    onTextChanged: if (length > kb.maxLength) remove(kb.maxLength, length)
                    onAccepted: kb.accepted(text)
                    Keys.onPressed: {
                        if (kb.isBack(event.key)) { kb.cancelled(); event.accepted = true }
                    }
                }
            }

            Text {
                width: parent.width
                text: "Use the on-screen keyboard · Done to save · Back to cancel"
                color: "#6c7086"
                font.family: kb.bodyFont()
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    function open(initial) {
        kb.text = initial || ""
        input.text = kb.text
        kb.visible = true
        input.forceActiveFocus()
        input.selectAll()
    }

    function close() { kb.visible = false }
}
