import QtQuick
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Live peak meter for the default microphone on a -60..0 dBFS scale, with
// guide zones (good speech peaks -18..-6 dBFS, red above -3 dBFS) and a
// peak-hold marker. Captures only while `monitoring` is true (panel open).
Item {
  id: root

  property var node: null
  property bool monitoring: false
  property bool muted: false
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.45)
  property string fontFamily: Style.font.family

  readonly property real db: Model.peakToDb(monitor.peak)
  property real holdDb: -Infinity
  readonly property string zone: Model.levelZone(holdDb)
  readonly property color clipColor: Color.urgent
  readonly property color goodColor: Color.accent

  function xFor(db) { return track.width * Model.dbToFraction(db) }

  // Explicit height: Column children with no height collapse to nothing.
  implicitHeight: trackHeight + labelGap + Math.max(label.implicitHeight, 14)
  height: implicitHeight
  readonly property real trackHeight: Math.max(8, Number(Style.space(8)) || 8)
  readonly property real labelGap: Math.max(4, Number(Style.space(4)) || 4)

  PwNodePeakMonitor {
    id: monitor
    node: root.node
    enabled: root.monitoring && !!root.node
  }

  onDbChanged: {
    if (db >= holdDb || !isFinite(holdDb)) { holdDb = db; holdTimer.restart() }
  }
  onMonitoringChanged: if (!monitoring) holdDb = -Infinity
  // Hold the peak for 1.5 s, then let it fall at 20 dB/s.
  Timer { id: holdTimer; interval: 1500; onTriggered: decay.start() }
  Timer {
    id: decay
    interval: 50
    repeat: true
    onTriggered: {
      var next = root.holdDb - 1
      if (next <= root.db || next < -60) { root.holdDb = root.db; stop() } else root.holdDb = next
    }
  }

  Rectangle {
    id: track
    width: parent.width
    height: root.trackHeight
    radius: height / 2
    color: Util.alpha(root.foreground, 0.12)
    clip: true
    opacity: root.muted ? 0.35 : 1

    // Guide zones.
    Rectangle {
      x: root.xFor(Model.GOOD_LOW_DB); width: root.xFor(Model.GOOD_HIGH_DB) - x
      height: parent.height; color: Util.alpha(root.goodColor, 0.22)
    }
    Rectangle {
      x: root.xFor(Model.CLIP_DB); width: parent.width - x
      height: parent.height; color: Util.alpha(root.clipColor, 0.25)
    }
    // Live level.
    Rectangle {
      height: parent.height
      width: root.xFor(root.db)
      color: Model.levelZone(root.db) === "clip" ? root.clipColor : root.foreground
      Behavior on width { NumberAnimation { duration: 60 } }
    }
    // Peak hold.
    Rectangle {
      visible: isFinite(root.holdDb) && root.holdDb > -60
      x: Math.max(0, root.xFor(root.holdDb) - width)
      width: Math.max(2, Style.space(2)); height: parent.height
      color: root.zone === "clip" ? root.clipColor : root.goodColor
    }
  }

  Text {
    id: label
    anchors.top: track.bottom
    anchors.topMargin: root.labelGap
    width: parent.width
    text: {
      if (root.muted) return "Microphone muted"
      if (!isFinite(root.holdDb) || root.holdDb < -60) return "Speak to check your level"
      var d = Math.round(root.holdDb) + " dBFS peak · "
      if (root.zone === "clip") return d + "too loud, lower the gain"
      if (root.zone === "hot") return d + "loud"
      if (root.zone === "good") return d + "good"
      return d + "too low, raise the gain"
    }
    textFormat: Text.PlainText
    color: root.zone === "clip" ? root.clipColor : root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }
}
