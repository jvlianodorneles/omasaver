import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dorneles.omasaver"

  // User Settings
  readonly property string defaultFontSetting: setting("defaultFont", "delta_corps_priest_1")
  readonly property bool showLabelSetting: setting("showLabel", true)

  // Live State
  property string inputText: "OMARCHY"
  property string currentFont: defaultFontSetting
  property string currentAlign: "left"
  property string renderedArt: ""
  property string statusMessage: "Ready"
  property bool isBusy: false

  readonly property string ctlScriptPath: Qt.resolvedUrl("scripts/omasaver-ctl.py").toString().replace(/^file:\/\//, "")

  readonly property var fontPresets: [
    { id: "delta_corps_priest_1", name: "⚡ Omarchy (Delta)", desc: "Signature font" },
    { id: "slant", name: "Slant", desc: "Italics modern" },
    { id: "standard", name: "Standard", desc: "Clean terminal" },
    { id: "banner", name: "Banner", desc: "Bold blocky" },
    { id: "block", name: "Block", desc: "Geometric" },
    { id: "doom", name: "Doom", desc: "Gaming classic" },
    { id: "starwars", name: "Star Wars", desc: "Sci-fi style" },
    { id: "alligator", name: "Alligator", desc: "Retro 3D" }
  ]

  function refreshArt() {
    if (renderProc.running) return
    renderProc.command = [root.ctlScriptPath, "render", root.inputText, root.currentFont, root.currentAlign]
    renderProc.running = true
  }

  function runAction(action) {
    if (actionProc.running) return
    root.isBusy = true
    actionProc.command = [root.ctlScriptPath, action, root.inputText, root.currentFont, root.currentAlign]
    actionProc.running = true
  }

  function openTui() {
    runAction("open-tui")
  }

  function triggerPreview() {
    runAction("preview")
    root.statusMessage = "Launching screensaver preview..."
  }

  function saveScreensaver() {
    runAction("save-screensaver")
    root.statusMessage = "Screensaver saved!"
  }

  function saveAbout() {
    runAction("save-about")
    root.statusMessage = "About logo updated!"
  }

  function copyArt() {
    runAction("copy")
    root.statusMessage = "Copied to clipboard!"
  }

  Component.onCompleted: {
    refreshArt()
  }

  IpcHandler {
    target: "dorneles.omasaver"
    function preview(): void { root.triggerPreview() }
    function saveScreensaver(): void { root.saveScreensaver() }
    function saveAbout(): void { root.saveAbout() }
    function openStudio(): void { studioWindow.open = true }
    function closeStudio(): void { studioWindow.open = false }
    function toggle(): void { studioWindow.open = !studioWindow.open }
    function copy(): void { root.copyArt() }
    function setText(txt: string): void {
      root.inputText = txt
      if (txtInput.text !== txt) txtInput.text = txt
      root.refreshArt()
    }
    function setFont(f: string): void {
      root.currentFont = f
      root.refreshArt()
    }
  }

  Process {
    id: renderProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.renderedArt = text || ""
      }
    }
  }

  Process {
    id: actionProc
    onExited: function(exitCode) {
      root.isBusy = false
      actionTimer.restart()
    }
  }

  Timer {
    id: actionTimer
    interval: 2500
    onTriggered: {
      root.statusMessage = "Ready"
    }
  }

  Timer {
    id: debounceTimer
    interval: 150
    onTriggered: root.refreshArt()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: root.vertical ? button.implicitHeight : root.barSize

  // Top Bar Button
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical || !root.showLabelSetting
      ? "\udb81\udf04"
      : "\udb81\udf04 Omasaver"
    active: studioWindow.open
    dimmed: !studioWindow.open
    useActiveColor: true
    activeColor: bar ? bar.urgent : Color.urgent
    fontSize: Style.font.body
    horizontalMargin: 6
    verticalPadding: 2
    tooltipText: "Omasaver: ASCII Art Studio & Screensaver Hub\n(Left-click: Open Studio | Right-click: Launch Full TUI | Middle-click: Preview Screensaver)"
    onPressed: function(btn) {
      if (btn === Qt.RightButton) root.openTui()
      else if (btn === Qt.MiddleButton) root.triggerPreview()
      else studioWindow.open = !studioWindow.open
    }
  }

  // Centered Studio Window with Exclusive Keyboard Focus
  PanelWindow {
    id: studioWindow
    visible: open
    property bool open: false

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "omarchy-omasaver-studio"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: {
      if (open) {
        root.refreshArt()
        txtInput.text = root.inputText
        Qt.callLater(function() {
          txtInput.forceActiveFocus()
          txtInput.selectAll()
        })
      }
    }

    // Scrim (darkened backdrop)
    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.72)

      MouseArea {
        anchors.fill: parent
        onClicked: studioWindow.open = false
      }
    }

    // Centered Studio Card
    BorderSurface {
      id: studioCard
      anchors.centerIn: parent
      width: Style.space(560)
      implicitHeight: cardContent.implicitHeight + Style.space(36)
      radius: Style.cornerRadius > 0 ? Style.cornerRadius + 2 : 8
      color: Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))

      // Prevent clicks inside card from closing modal
      MouseArea {
        anchors.fill: parent
        onClicked: {}
      }

      Column {
        id: cardContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(18)
        spacing: Style.spacing.sm

        // Header Row
        Row {
          width: parent.width
          spacing: Style.spacing.sm

          Text {
            text: "\udb81\udf04"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            width: parent.width - Style.space(90)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              text: "Omasaver Studio"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            Text {
              text: root.statusMessage === "Ready" ? ("Font: " + root.currentFont) : root.statusMessage
              color: root.statusMessage === "Ready" ? Qt.darker(Color.foreground, 1.4) : Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Button {
            iconText: "\udb80\udf93"
            tooltipText: "Launch Full Terminal TUI Studio"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: {
              studioWindow.open = false
              root.openTui()
            }
          }

          Button {
            iconText: "\udb80\udd56"
            tooltipText: "Close (Esc)"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: studioWindow.open = false
          }
        }

        PanelSeparator { foreground: Color.foreground }

        // Input Section
        Row {
          width: parent.width
          spacing: Style.spacing.sm

          Text {
            text: "Text:"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(45)
          }

          TextField {
            id: txtInput
            width: parent.width - Style.space(55)
            text: root.inputText
            placeholderText: "Type text to convert instantly..."
            foreground: Color.foreground
            accent: Color.accent
            selectByMouse: true
            anchors.verticalCenter: parent.verticalCenter
            focus: true

            onTextChanged: {
              if (root.inputText !== text) {
                root.inputText = text
                debounceTimer.restart()
              }
            }
            onAccepted: {
              root.refreshArt()
            }
            Keys.onEscapePressed: {
              studioWindow.open = false
            }
          }
        }

        // Font Preset Buttons
        PanelSectionHeader {
          text: "FONT PRESETS"
          foreground: Color.foreground
        }

        Grid {
          width: parent.width
          columns: 4
          spacing: Style.spacing.xs

          Repeater {
            model: root.fontPresets

            delegate: BorderSurface {
              required property var modelData
              required property int index

              width: (parent.width - Style.spacing.xs * 3) / 4
              implicitHeight: Style.space(32)
              radius: Style.cornerRadius > 0 ? Style.cornerRadius : 4

              readonly property bool isSelected: root.currentFont === modelData.id

              color: isSelected
                ? Style.selectedFillFor(Color.foreground, Color.accent)
                : Style.controlFill(false, fontMouse.containsMouse, Color.foreground, Color.accent)
              borderSpec: Border.controlSpec(isSelected ? "selected" : (fontMouse.containsMouse ? "hover-cursor" : "normal"), Color.foreground, Color.accent)

              Text {
                anchors.centerIn: parent
                text: modelData.name
                color: isSelected ? Color.accent : Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: isSelected
                elide: Text.ElideRight
                width: parent.width - Style.space(8)
                horizontalAlignment: Text.AlignHCenter
              }

              MouseArea {
                id: fontMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.currentFont = modelData.id
                  root.refreshArt()
                  txtInput.forceActiveFocus()
                }
              }
            }
          }
        }

        // ASCII Live Preview Box
        PanelSectionHeader {
          text: "LIVE ASCII PREVIEW"
          foreground: Color.foreground
        }

        BorderSurface {
          width: parent.width
          height: Style.space(170)
          radius: Style.cornerRadius > 0 ? Style.cornerRadius : 4
          color: Qt.rgba(0, 0, 0, 0.55)
          borderSpec: Border.controlSpec("normal", Color.foreground, Color.accent)

          Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: Style.spacing.sm
            contentWidth: Math.max(width, asciiText.implicitWidth)
            contentHeight: Math.max(height, asciiText.implicitHeight)
            clip: true

            Text {
              id: asciiText
              text: root.renderedArt || "Generating..."
              color: Color.accent
              font.family: Style.font.familyMono || "monospace"
              font.pixelSize: 10
              lineHeight: 1.0
              wrapMode: Text.NoWrap
            }
          }
        }

        PanelSeparator { foreground: Color.foreground }

        // Action Buttons Grid
        Grid {
          width: parent.width
          columns: 4
          spacing: Style.spacing.xs

          // Button 1: Preview
          BorderSurface {
            width: (parent.width - Style.spacing.xs * 3) / 4
            height: Style.space(38)
            radius: Style.cornerRadius > 0 ? Style.cornerRadius : 4
            color: Style.controlFill(false, btn1Mouse.containsMouse, Color.foreground, Color.accent)
            borderSpec: Border.controlSpec(btn1Mouse.containsMouse ? "hover-cursor" : "normal", Color.foreground, Color.accent)

            Row {
              anchors.centerIn: parent
              spacing: 4
              Text { text: "\udb81\udf04"; color: Color.accent; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Preview"; color: Color.foreground; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: btn1Mouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.triggerPreview()
            }
          }

          // Button 2: Save Screensaver
          BorderSurface {
            width: (parent.width - Style.spacing.xs * 3) / 4
            height: Style.space(38)
            radius: Style.cornerRadius > 0 ? Style.cornerRadius : 4
            color: Style.controlFill(false, btn2Mouse.containsMouse, Color.foreground, Color.accent)
            borderSpec: Border.controlSpec(btn2Mouse.containsMouse ? "hover-cursor" : "normal", Color.foreground, Color.accent)

            Row {
              anchors.centerIn: parent
              spacing: 4
              Text { text: "\udb80\udc19"; color: Color.foreground; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Screensaver"; color: Color.foreground; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: btn2Mouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.saveScreensaver()
            }
          }

          // Button 3: Save About Logo
          BorderSurface {
            width: (parent.width - Style.spacing.xs * 3) / 4
            height: Style.space(38)
            radius: Style.cornerRadius > 0 ? Style.cornerRadius : 4
            color: Style.controlFill(false, btn3Mouse.containsMouse, Color.foreground, Color.accent)
            borderSpec: Border.controlSpec(btn3Mouse.containsMouse ? "hover-cursor" : "normal", Color.foreground, Color.accent)

            Row {
              anchors.centerIn: parent
              spacing: 4
              Text { text: "\udb81\udde0"; color: Color.foreground; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "About Logo"; color: Color.foreground; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: btn3Mouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.saveAbout()
            }
          }

          // Button 4: Copy
          BorderSurface {
            width: (parent.width - Style.spacing.xs * 3) / 4
            height: Style.space(38)
            radius: Style.cornerRadius > 0 ? Style.cornerRadius : 4
            color: Style.controlFill(false, btn4Mouse.containsMouse, Color.foreground, Color.accent)
            borderSpec: Border.controlSpec(btn4Mouse.containsMouse ? "hover-cursor" : "normal", Color.foreground, Color.accent)

            Row {
              anchors.centerIn: parent
              spacing: 4
              Text { text: "\udb80\udec5"; color: Color.foreground; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Copy"; color: Color.foreground; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
              id: btn4Mouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.copyArt()
            }
          }
        }
      }
    }
  }
}
