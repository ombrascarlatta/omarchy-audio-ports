import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// A copy of the Omarchy bar tooltip (same surface, colors, font, padding,
// 6 px offset and 400 ms delay) whose text is a live binding, so it can stay
// open while the value changes. Click-through: it has an empty input mask.
PopupWindow {
  id: root

  property Item target: null
  property var bar: null
  property string text: ""
  property bool hovered: false
  property bool suppressed: false
  property bool shown: false
  readonly property string position: bar && bar.position ? String(bar.position) : "top"
  readonly property string fontFamily: bar && bar.fontFamily ? bar.fontFamily : Style.font.family

  onHoveredChanged: {
    if (hovered && !suppressed) delay.restart()
    else { delay.stop(); shown = false }
  }
  onSuppressedChanged: if (suppressed) { delay.stop(); shown = false }

  Timer { id: delay; interval: 400; onTriggered: root.shown = root.hovered && !root.suppressed }

  visible: shown && !!target && text !== "" && !!target.QsWindow.window
  color: "transparent"
  implicitWidth: Math.ceil(bubble.implicitWidth)
  implicitHeight: Math.ceil(bubble.implicitHeight)
  mask: Region {}

  onImplicitWidthChanged: if (visible) anchor.updateAnchor()

  anchor {
    window: root.target ? root.target.QsWindow.window : null
    adjustment: PopupAdjustment.Slide
    edges: Edges.Top | Edges.Left
    gravity: Edges.Bottom | Edges.Right
    rect.width: 1
    rect.height: 1

    onAnchoring: {
      var t = root.target
      var window = t ? t.QsWindow.window : null
      if (!window) return
      var w = root.implicitWidth, h = root.implicitHeight
      var x = t.width / 2 - w / 2, y = t.height + 6
      if (root.position === "bottom") y = -h - 6
      else if (root.position === "left") { x = t.width + 6; y = t.height / 2 - h / 2 }
      else if (root.position === "right") { x = -w - 6; y = t.height / 2 - h / 2 }
      var p = window.contentItem.mapFromItem(t, x, y)
      root.anchor.rect.x = Math.round(p.x)
      root.anchor.rect.y = Math.round(p.y)
    }
  }

  BorderSurface {
    id: bubble
    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 14
    color: Color.tooltip.background
    borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
    radius: Style.cornerRadius

    Text {
      id: label
      textFormat: Text.PlainText
      anchors.centerIn: parent
      text: root.text
      color: Color.tooltip.text
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }
  }
}
