import QtQuick
import qs.Commons
import qs.Ui
import Quickshell.Services.Pipewire
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "maxime.audio-ports"

  readonly property var portService: {
    var host = bar && bar.shell ? bar.shell : null
    return host && typeof host.serviceFor === "function" ? host.serviceFor(moduleName) : null
  }
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  property real wheelAccumulator: 0
  // Read volume/mute straight from PipeWire so the icon follows every change
  // (media keys, other apps), not only the service's own.
  readonly property var sinkNode: Pipewire.defaultAudioSink
  readonly property real liveVolume: sinkNode && sinkNode.audio ? Number(sinkNode.audio.volume || 0) : 0
  readonly property bool liveMuted: !sinkNode || !sinkNode.audio || sinkNode.audio.muted === true
  PwObjectTracker { objects: root.sinkNode ? [root.sinkNode] : [] }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.anchorItem = button
    target.hostWidget = root
    target.service = root.portService
  }
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  // One glyph only: volume level of the default output, or muted.
  function glyph() {
    var s = portService
    if (!s) return "󰕾"
    if (s.error) return ""
    var hp = Model.portKind(s.currentSinkPort) === "headphones"
    return Model.volumeGlyph(root.liveVolume, root.liveMuted, hp && !root.liveMuted)
  }

  function tooltip() {
    var s = portService
    if (!s) return "Audio Ports service unavailable"
    if (s.error) return s.error
    var out = s.currentSinkPort ? s.currentSinkPort.description : "No output"
    var vol = root.liveMuted ? "muted" : Math.round(root.liveVolume * 100) + "%"
    var mic = s.currentSourcePort ? s.currentSourcePort.description : "No microphone"
    return out + " · " + vol + "\n" + mic + (s.inputMuted ? " · muted" : "")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onPortServiceChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  // BarIconButton is what the built-in Audio widget uses: same icon size and slot.
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph()
    // Highlighted on error, or as a subtle hint while the microphone is muted.
    active: !!root.portService && (root.portService.error !== "" || root.portService.inputMuted)
    tooltipText: root.tooltip()
    onPressed: function(b) {
      if (b === Qt.RightButton) { if (root.portService) root.portService.muteKey() }
      else root.togglePanel()
    }
    onWheelMoved: function(delta) {
      if (!root.portService) return
      var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
      root.wheelAccumulator = wheel.remainder
      if (wheel.steps === 0) return
      // Same command as the volume keys: 5% per notch, clamped, with the OSD.
      root.portService.volumeKey(wheel.steps)
    }
  }
}
