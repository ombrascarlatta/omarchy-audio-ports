import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "maxime.audio-ports"
  manageIpc: false

  property var service: null
  property Item anchorItem: null
  property Item hostWidget: null
  property bool cursorActive: false
  property string cursorId: ""
  property bool shortcutsExpanded: false

  readonly property int serviceRevision: service ? service.revision : 0
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var sinks: { var r = serviceRevision; return service ? service.sinks : [] }
  readonly property var sources: { var r = serviceRevision; return service ? service.sources : [] }
  readonly property var cursorTargets: Model.buildTargets(sinks, sources)

  function currentTarget() {
    var i = Model.indexOfId(cursorTargets, cursorId)
    return i >= 0 ? cursorTargets[i] : null
  }
  function selectTarget(id) {
    if (Model.indexOfId(cursorTargets, id) < 0) return
    cursorActive = true
    cursorId = id
  }
  function moveCursor(delta) { var next = Model.move(cursorTargets, cursorId, delta); if (next) selectTarget(next) }
  function choose(kind, device, port) { if (service && device && port) service.selectPort(kind, device.name, port.name) }
  function sectionKind() {
    var t = currentTarget()
    return t ? t.direction : "sink"
  }
  function adjustVolume(kind, delta) {
    if (!service) return
    if (kind === "source") service.setInputVolume(service.inputVolume + delta * 0.05)
    else service.setOutputVolume(service.outputVolume + delta * 0.05)
  }
  function toggleMute(kind) {
    if (!service) return
    if (kind === "source") service.toggleInputMute()
    else service.toggleOutputMute()
  }
  function activateCursor() {
    var t = currentTarget()
    if (!t) return
    if (t.kind === "port") choose(t.direction, t.device, t.port)
    else toggleMute(t.direction)
  }
  function shortcutGuide() {
    return "J/K or ↑/↓  Navigate\n"
      + "Enter/Space  Select port (on a slider: mute)\n"
      + "H/L or ←/→  Volume of the current section\n"
      + "M  Mute current section\n"
      + "O / I  Next output / input port\n"
      + "Esc  Close"
  }
  function ensureCursorVisible(item) {
    if (!item || !scroll) return
    var margin = Style.space(6)
    var maximum = Math.max(0, (scroll.contentHeight || 0) - scroll.height)
    var top = item.mapToItem(scroll.contentItem, 0, 0).y
    var bottom = top + (item.height || 0)
    if (top < scroll.contentY + margin) scroll.contentY = Math.max(0, Math.min(maximum, top - margin))
    else if (bottom > scroll.contentY + scroll.height - margin)
      scroll.contentY = Math.max(0, Math.min(maximum, bottom + margin - scroll.height))
  }

  onOpenedChanged: {
    if (!opened) return
    cursorActive = false
    cursorId = cursorTargets.length > 0 ? cursorTargets[0].id : ""
    shortcutsExpanded = false
    if (service) service.refresh()
    Qt.callLater(function() { scroll.contentY = 0; keyCatcher.forceActiveFocus() })
  }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(420))
    contentHeight: popup.fittedContentHeight(
      fixedHeader.implicitHeight + fixedFooter.implicitHeight
        + Style.spacing.panelGap * 2 + content.implicitHeight,
      Style.space(680))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0) root.adjustVolume(root.sectionKind(), dx)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (!root.service) return
        var t = String(text).toLowerCase()
        if (text === "?") root.shortcutsExpanded = !root.shortcutsExpanded
        else if (t === "m") root.toggleMute(root.sectionKind())
        else if (t === "o") root.service.cyclePort("sink")
        else if (t === "i") root.service.cyclePort("source")
      }

      Column {
        id: fixedHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.spacing.panelGap

        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)
          Text {
            id: heroIcon
            text: root.service ? Model.portGlyph("sink", root.service.currentSinkPort) : "󰓃"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }
          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            Text {
              width: parent.width
              text: "Audio Ports"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              text: {
                var s = root.service
                if (!s) return "UNAVAILABLE"
                var o = s.currentSinkPort ? s.currentSinkPort.description : "—"
                var i = s.currentSourcePort ? s.currentSourcePort.description : "—"
                return (o + " · " + i).toUpperCase()
              }
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
            }
          }
        }

        Text {
          visible: !root.service || !root.service.ready || root.service.error !== ""
          width: parent.width
          text: !root.service ? "Audio Ports service unavailable."
            : (root.service.error || "Reading audio ports…")
          textFormat: Text.PlainText
          color: root.service && root.service.ready ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        PanelSeparator { foreground: root.foreground }
      }

      Flickable {
        id: scroll
        anchors.top: fixedHeader.bottom
        anchors.topMargin: Style.spacing.panelGap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: fixedFooter.top
        anchors.bottomMargin: Style.spacing.panelGap
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        Column {
          id: content
          width: scroll.width
          spacing: Style.spacing.lg

          VolumeSection {
            width: parent.width
            panelController: root
            bar: root.bar
            title: "OUTPUT"
            targetId: "output-volume"
            volume: root.service ? root.service.outputVolume : 0
            muted: !!root.service && root.service.outputMuted
            available: !!root.service && root.service.hasOutput
            foreground: root.foreground
            dim: root.dim
            fontFamily: root.fontFamily
            onVolumeMoved: function(value) { if (root.service) root.service.setOutputVolume(value) }
            onMuteToggled: root.toggleMute("sink")
          }

          Column {
            width: parent.width
            spacing: Style.spacing.xs
            Repeater {
              model: root.sinks
              delegate: Repeater {
                id: portRepeater
                required property var modelData
                readonly property var deviceData: modelData
                model: deviceData.ports
                delegate: PortRow {
                  required property var modelData
                  width: content.width
                  panelController: root
                  kind: "sink"
                  device: portRepeater.deviceData
                  port: modelData
                  foreground: root.foreground
                  dim: root.dim
                  fontFamily: root.fontFamily
                }
              }
            }
          }

          VolumeSection {
            width: parent.width
            panelController: root
            bar: root.bar
            title: "INPUT"
            targetId: "input-volume"
            muteGlyph: "󰍭"
            unmuteGlyph: "󰍬"
            volume: root.service ? root.service.inputVolume : 0
            muted: !!root.service && root.service.inputMuted
            available: !!root.service && root.service.hasInput
            foreground: root.foreground
            dim: root.dim
            fontFamily: root.fontFamily
            onVolumeMoved: function(value) { if (root.service) root.service.setInputVolume(value) }
            onMuteToggled: root.toggleMute("source")
          }

          Column {
            width: parent.width
            spacing: Style.spacing.xs
            Repeater {
              model: root.sources
              delegate: Repeater {
                id: portRepeater
                required property var modelData
                readonly property var deviceData: modelData
                model: deviceData.ports
                delegate: PortRow {
                  required property var modelData
                  width: content.width
                  panelController: root
                  kind: "source"
                  device: portRepeater.deviceData
                  port: modelData
                  foreground: root.foreground
                  dim: root.dim
                  fontFamily: root.fontFamily
                }
              }
            }
          }
        }
      }

      Column {
        id: fixedFooter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: Style.spacing.sm

        CursorSurface {
          visible: root.shortcutsExpanded
          width: parent.width
          implicitHeight: shortcutsText.implicitHeight + Style.spacing.controlPaddingY * 2
          bordered: true
          foreground: root.foreground
          Text {
            id: shortcutsText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.spacing.controlPaddingX
            anchors.rightMargin: Style.spacing.controlPaddingX
            text: root.shortcutGuide()
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            lineHeight: 1.25
          }
        }

        Item {
          width: parent.width
          implicitHeight: shortcutsHelp.implicitHeight
          PanelActionButton {
            id: shortcutsHelp
            anchors.right: parent.right
            iconText: ""
            foreground: root.shortcutsExpanded ? root.foreground : root.dim
            onClicked: root.shortcutsExpanded = !root.shortcutsExpanded
          }
        }
      }
    }
  }
}
