import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// One selectable port of one device. Selected = this device is the default
// and this port is its active port.
Item {
  id: root

  property var panelController: null
  property string kind: "sink"
  property var device: null
  property var port: null
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.45)
  property string fontFamily: Style.font.family

  readonly property string rowId: device && port ? Model.rowId(kind, device.name, port.name) : ""
  readonly property bool selected: !!device && !!port && device.isDefault && device.activePort === port.name
  readonly property bool activeOnDevice: !!device && !!port && device.activePort === port.name
  readonly property bool keyboardSelected: !!panelController && panelController.cursorActive
    && panelController.cursorId === rowId

  implicitHeight: Math.max(Style.spacing.popupRowHeight + Style.spacing.sm, Style.space(36))

  onKeyboardSelectedChanged: if (keyboardSelected && panelController) panelController.ensureCursorVisible(root)

  CursorSurface {
    anchors.fill: parent
    hasCursor: root.keyboardSelected
    current: root.selected
    currentFill: Util.alpha(Style.selectedStateColor(root.foreground, Color.accent),
      Math.max(Style.selectedFillAlpha, 0.18))
    foreground: root.foreground
    opacity: root.port && root.port.availability === "unavailable" ? 0.62 : 1
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: if (root.panelController) root.panelController.selectTarget(root.rowId)
    onClicked: if (root.panelController) root.panelController.choose(root.kind, root.device, root.port)
  }

  Text {
    id: glyph
    anchors.left: parent.left
    anchors.leftMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(24)
    text: root.selected ? "✓" : Model.portGlyph(root.kind, root.port)
    color: root.selected ? Color.accent : root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    font.bold: root.selected
  }

  Column {
    anchors.left: glyph.right
    anchors.leftMargin: Style.space(8)
    anchors.right: parent.right
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(1)

    Text {
      width: parent.width
      text: root.port ? root.port.description : ""
      textFormat: Text.PlainText
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: root.selected
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      text: (root.device ? root.device.description : "") + " · " + Model.availabilityLabel(root.port)
        + (root.activeOnDevice && !root.selected ? " · active (not default)" : "")
      textFormat: Text.PlainText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }
}
