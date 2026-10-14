import QtQuick
import qs.Commons
import qs.Ui

// Section header with percentage and mute button, plus a volume slider.
Column {
  id: root

  property var panelController: null
  property var bar: null
  property string title: "OUTPUT"
  property string targetId: "output-volume"
  property real volume: 0
  property bool muted: false
  property bool available: false
  property string muteGlyph: "󰝟"
  property string unmuteGlyph: "󰕾"
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.45)
  property string fontFamily: Style.font.family
  signal volumeMoved(real value)
  signal muteToggled()

  spacing: Style.spacing.md

  Item {
    width: parent.width
    implicitHeight: Math.max(header.implicitHeight, muteButton.implicitHeight)
    PanelSectionHeader {
      id: header
      text: root.title
      foreground: root.foreground
      fontFamily: root.fontFamily
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: root.available ? Math.round((slider.dragging ? slider.liveValue : root.volume) * 100) + "%" : "—"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      opacity: root.muted ? 0.5 : 1
      anchors.right: muteButton.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
    }
    PanelActionButton {
      id: muteButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      iconText: root.muted ? root.muteGlyph : root.unmuteGlyph
      foreground: root.muted ? Color.urgent : root.dim
      onClicked: root.muteToggled()
    }
  }

  CursorSurface {
    id: sliderRow
    width: parent.width
    height: slider.implicitHeight + Style.spacing.controlGap
    hasCursor: !!root.panelController && root.panelController.cursorActive
      && root.panelController.cursorId === root.targetId
    foreground: root.foreground
    outline: true
    onHasCursorChanged: if (hasCursor && root.panelController) root.panelController.ensureCursorVisible(sliderRow)
    PanelSlider {
      id: slider
      anchors.fill: parent
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      bar: root.bar
      minimum: 0
      maximum: 1
      step: 0.05
      value: root.volume
      enabled: root.available
      opacity: root.muted ? 0.5 : 1
      onMoved: function(value) { root.volumeMoved(value) }
      onRightClicked: root.muteToggled()
    }
    HoverHandler { onHoveredChanged: if (hovered && root.panelController) root.panelController.selectTarget(root.targetId) }
  }
}
