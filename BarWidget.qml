import QtQuick
import qs.Commons
import qs.Ui
import Quickshell.Services.Pipewire
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "ombrascarlatta.audio-ports"

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

  // Like the volume keys, without their OSD: 5% per notch, clamped to
  // 0..100%, and changing the volume unmutes.
  function stepVolume(steps) {
    if (!sinkNode || !sinkNode.audio || steps === 0) return
    sinkNode.audio.muted = false
    sinkNode.audio.volume = Model.clampVolume(Math.round((liveVolume + steps * 0.05) * 100) / 100)
  }
  function toggleMute() {
    if (sinkNode && sinkNode.audio) sinkNode.audio.muted = !sinkNode.audio.muted
  }

  // Our own tooltip (BarTooltip.qml) instead of the bar's, which copies its
  // text when shown; this one stays open and updates while scrolling.
  readonly property string liveTooltip: tooltip()
  BarTooltip {
    target: button
    bar: root.bar
    text: root.liveTooltip
    hovered: button.tooltipHovered === true
    suppressed: root.opened || clickHide
  }
  // A click hides the tooltip until the pointer leaves, like the native one.
  property bool clickHide: false
  Connections {
    target: button
    function onTooltipHoveredChanged() { if (!button.tooltipHovered) root.clickHide = false }
  }

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
    tooltipText: ""  // see BarTooltip above
    onPressed: function(b) {
      root.clickHide = true
      if (b === Qt.RightButton) root.toggleMute()
      else root.togglePanel()
    }
    onWheelMoved: function(delta) {
      var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
      root.wheelAccumulator = wheel.remainder
      if (wheel.steps === 0) return
      root.stepVolume(wheel.steps)
    }
  }
}
