import QtQuick
import qs.Commons
import qs.Ui
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
    return Model.volumeGlyph(s.outputVolume, s.outputMuted || !s.hasOutput)
  }

  function tooltip() {
    var s = portService
    if (!s) return "Audio Ports service unavailable"
    if (s.error) return s.error
    var out = s.currentSinkPort ? s.currentSinkPort.description : "No output"
    var vol = s.outputMuted ? "muted" : Math.round(s.outputVolume * 100) + "%"
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

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph()
    // Highlighted on error, or as a subtle hint while the microphone is muted.
    active: !!root.portService && (root.portService.error !== "" || root.portService.inputMuted)
    tooltipText: root.tooltip()
    onPressed: root.togglePanel()
    onWheelMoved: function(delta) {
      if (!root.portService) return
      var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
      root.wheelAccumulator = wheel.remainder
      if (wheel.steps !== 0) root.portService.setOutputVolume(root.portService.outputVolume + wheel.steps * 0.02)
    }
  }
}
