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
  property string currentMode: (settings && settings.mode !== undefined) ? String(settings.mode) : setting("mode", "always")
  readonly property string defaultFontSetting: setting("defaultFont", "delta_corps_priest_1")
  readonly property bool showLabelSetting: setting("showLabel", true)

  onSettingsChanged: {
    currentMode = (settings && settings.mode !== undefined) ? String(settings.mode) : setting("mode", "always")
  }

  readonly property bool isWidgetVisible: currentMode === "always" || (studioWindow && studioWindow.open) || isPreviewing || isBusy

  // Live State
  property string inputText: "OMARCHY"
  property string currentFont: defaultFontSetting
  property string currentAlign: "left"
  property string renderedArt: ""
  property string statusMessage: "Ready"
  property bool isBusy: false
  property bool isPreviewing: false

  readonly property string ctlScriptPath: Qt.resolvedUrl("scripts/omasaver-ctl.py").toString().replace(/^file:\/\//, "")

  readonly property var fontPresets: [
    { id: "delta_corps_priest_1", name: "⚡ Delta Corps" },
    { id: "slant", name: "Slant" },
    { id: "standard", name: "Standard" },
    { id: "banner", name: "Banner" },
    { id: "block", name: "Block" },
    { id: "doom", name: "Doom" },
    { id: "epic", name: "Epic" },
    { id: "starwars", name: "Star Wars" },
    { id: "isometric1", name: "Isometric" },
    { id: "alligator", name: "Alligator" },
    { id: "graffiti", name: "Graffiti" },
    { id: "speed", name: "Speed" },
    { id: "sub-zero", name: "Sub-Zero" },
    { id: "cyberlarge", name: "Cyberlarge" },
    { id: "larry3d", name: "Larry 3D" },
    { id: "shadow", name: "Shadow" },
    { id: "ogre", name: "Ogre" },
    { id: "colossal", name: "Colossal" },
    { id: "cosmic", name: "Cosmic" },
    { id: "caligraphy", name: "Caligraphy" }
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

  function triggerPreview() {
    root.isPreviewing = true
    studioWindow.open = false
    runAction("preview")
  }

  function saveScreensaver() {
    runAction("save-screensaver")
    root.statusMessage = "Screensaver saved!"
  }

  function saveAbout() {
    runAction("save-about")
    root.statusMessage = "About logo saved!"
  }

  function copyArt() {
    runAction("copy")
    root.statusMessage = "Copied to clipboard!"
  }

  function restoreDefaults() {
    runAction("restore-defaults")
    root.statusMessage = "Default branding restored!"
  }

  Component.onCompleted: {
    refreshArt()
  }

  IpcHandler {
    target: "dorneles.omasaver"
    function preview(): void { root.triggerPreview() }
    function saveScreensaver(): void { root.saveScreensaver() }
    function saveAbout(): void { root.saveAbout() }
    function restoreDefaults(): void { root.restoreDefaults() }
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
      if (root.isPreviewing) {
        root.isPreviewing = false
        studioWindow.open = true
      }
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

  visible: isWidgetVisible
  implicitWidth: !isWidgetVisible ? 0 : button.implicitWidth
  implicitHeight: !isWidgetVisible ? 0 : (root.vertical ? button.implicitHeight : root.barSize)

  // Top Bar Button
  WidgetButton {
    id: button
    visible: root.isWidgetVisible
    anchors.fill: parent
    bar: root.bar
    text: root.vertical || !root.showLabelSetting
      ? "󱄄"
      : "󱄄 omasaver"
    active: studioWindow.open
    dimmed: !studioWindow.open
    useActiveColor: true
    activeColor: bar ? bar.urgent : Color.urgent
    fontSize: Style.font.body
    horizontalMargin: 6
    verticalPadding: 2
    tooltipText: "omasaver: ASCII Art & Screensaver Hub\n(Click: Open | Middle-click: Preview Screensaver)"
    onPressed: function(btn) {
      if (btn === Qt.MiddleButton) root.triggerPreview()
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
      color: Qt.rgba(0, 0, 0, 0.75)

      MouseArea {
        anchors.fill: parent
        onClicked: studioWindow.open = false
      }
    }

    // Centered Large Studio Card
    BorderSurface {
      id: studioCard
      anchors.centerIn: parent
      width: Style.space(780)
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
        anchors.margins: Style.space(20)
        spacing: Style.spacing.sm

        // Header Row
        Row {
          width: parent.width
          spacing: Style.spacing.sm

          Text {
            text: "󱄄"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            width: parent.width - Style.space(50)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              text: "omasaver"
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

        // Font Presets Section (5 columns grid with 20 fonts)
        PanelSectionHeader {
          text: "FONT PRESETS (" + root.fontPresets.length + " AVAILABLE)"
          foreground: Color.foreground
        }

        Grid {
          width: parent.width
          columns: 5
          spacing: Style.spacing.xs

          Repeater {
            model: root.fontPresets

            delegate: BorderSurface {
              required property var modelData
              required property int index

              width: (parent.width - Style.spacing.xs * 4) / 5
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

        // ASCII Live Preview Box (Enlarged)
        PanelSectionHeader {
          text: "LIVE ASCII PREVIEW"
          foreground: Color.foreground
        }

        BorderSurface {
          width: parent.width
          height: Style.space(230)
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

        // Action Buttons Grid (5 columns: Preview, Save, Save About Logo, Copy, Restore Defaults)
        Grid {
          width: parent.width
          columns: 5
          spacing: Style.spacing.xs

          // Button 1: Preview
          BorderSurface {
            width: (parent.width - Style.spacing.xs * 4) / 5
            height: Style.space(38)
            radius: Style.cornerRadius > 0 ? Style.cornerRadius : 4
            color: Style.controlFill(false, btn1Mouse.containsMouse, Color.foreground, Color.accent)
            borderSpec: Border.controlSpec(btn1Mouse.containsMouse ? "hover-cursor" : "normal", Color.foreground, Color.accent)

            Row {
              anchors.centerIn: parent
              spacing: 5
              Text { text: "󱄄"; color: Color.accent; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
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

          // Button 2: Save
          BorderSurface {
            width: (parent.width - Style.spacing.xs * 4) / 5
            height: Style.space(38)
            radius: Style.cornerRadius > 0 ? Style.cornerRadius : 4
            color: Style.controlFill(false, btn2Mouse.containsMouse, Color.foreground, Color.accent)
            borderSpec: Border.controlSpec(btn2Mouse.containsMouse ? "hover-cursor" : "normal", Color.foreground, Color.accent)

            Row {
              anchors.centerIn: parent
              spacing: 5
              Text { text: "\udb80\udc19"; color: Color.foreground; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Save"; color: Color.foreground; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
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
            width: (parent.width - Style.spacing.xs * 4) / 5
            height: Style.space(38)
            radius: Style.cornerRadius > 0 ? Style.cornerRadius : 4
            color: Style.controlFill(false, btn3Mouse.containsMouse, Color.foreground, Color.accent)
            borderSpec: Border.controlSpec(btn3Mouse.containsMouse ? "hover-cursor" : "normal", Color.foreground, Color.accent)

            Row {
              anchors.centerIn: parent
              spacing: 5
              Text { text: "\udb81\udde0"; color: Color.foreground; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Save About Logo"; color: Color.foreground; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight }
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
            width: (parent.width - Style.spacing.xs * 4) / 5
            height: Style.space(38)
            radius: Style.cornerRadius > 0 ? Style.cornerRadius : 4
            color: Style.controlFill(false, btn4Mouse.containsMouse, Color.foreground, Color.accent)
            borderSpec: Border.controlSpec(btn4Mouse.containsMouse ? "hover-cursor" : "normal", Color.foreground, Color.accent)

            Row {
              anchors.centerIn: parent
              spacing: 5
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

          // Button 5: Restore Defaults
          BorderSurface {
            width: (parent.width - Style.spacing.xs * 4) / 5
            height: Style.space(38)
            radius: Style.cornerRadius > 0 ? Style.cornerRadius : 4
            color: Style.controlFill(false, btn5Mouse.containsMouse, Color.foreground, Color.accent)
            borderSpec: Border.controlSpec(btn5Mouse.containsMouse ? "hover-cursor" : "normal", Color.foreground, Color.accent)

            Row {
              anchors.centerIn: parent
              spacing: 5
              Text { text: "\udb80\uddbb"; color: Color.foreground; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
              Text { text: "Restore Defaults"; color: Color.foreground; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight }
            }
            MouseArea {
              id: btn5Mouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.restoreDefaults()
            }
          }
        }
      }
    }
  }
}
