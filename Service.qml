import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Model.js" as Model

// Singleton service: tracks ALSA sinks/sources and their ports, and switches
// ports through the bounded helpers in scripts/. Volume and mute use
// Quickshell's native PipeWire bindings for the default devices.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property var pluginRegistry: null

  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "maxime.audio-ports"
  // Scoped host manifests omit installation paths, so resolve from this file.
  readonly property string sourceDir: {
    var url = String(Qt.resolvedUrl("."))
    return url.indexOf("file:///") === 0
      ? decodeURIComponent(url.substring(7)).replace(/\/$/, "") : ""
  }
  readonly property string testBinDir: manifest && manifest.__testBinDir ? String(manifest.__testBinDir) : ""
  readonly property string home: Quickshell.env("HOME")
  readonly property string runtimeDir: String(Quickshell.env("XDG_RUNTIME_DIR") || "")
  readonly property var childEnvironment: {
    var env = { "HOME": home, "LANG": "C", "LC_ALL": "C", "PATH": "/usr/bin:/bin" }
    var stateHome = String(Quickshell.env("XDG_STATE_HOME") || "")
    if (stateHome) env["XDG_STATE_HOME"] = stateHome
    if (runtimeDir) {
      env["XDG_RUNTIME_DIR"] = runtimeDir
      env["PULSE_SERVER"] = "unix:" + runtimeDir + "/pulse/native"
    }
    if (testBinDir) env["AUDIO_PORTS_TEST_BIN"] = testBinDir
    return env
  }

  readonly property var defaultSink: Pipewire.defaultAudioSink
  readonly property var defaultSource: Pipewire.defaultAudioSource

  PwObjectTracker { objects: [root.defaultSink, root.defaultSource] }

  property var sinks: []
  property var sources: []
  property bool ready: false
  property bool stopping: false
  property bool refreshPending: false
  property string statusError: ""
  property string switchError: ""
  property var queuedSwitch: null
  property int revision: 0

  readonly property string setupError: manifest && !sourceDir
    ? "Plugin component has no local source directory; helper scripts cannot run" : ""
  readonly property string error: setupError || statusError || switchError
  readonly property var currentSink: Model.defaultDevice(sinks)
  readonly property var currentSource: Model.defaultDevice(sources)
  readonly property var currentSinkPort: Model.activePort(currentSink)
  readonly property var currentSourcePort: Model.activePort(currentSource)

  readonly property bool hasOutput: !!(defaultSink && defaultSink.audio)
  readonly property bool hasInput: !!(defaultSource && defaultSource.audio)
  readonly property real outputVolume: hasOutput ? Number(defaultSink.audio.volume || 0) : 0
  readonly property real inputVolume: hasInput ? Number(defaultSource.audio.volume || 0) : 0
  readonly property bool outputMuted: hasOutput && defaultSink.audio.muted === true
  readonly property bool inputMuted: hasInput && defaultSource.audio.muted === true

  function script(name) { return sourceDir + "/scripts/" + name }
  function bounded(seconds, name, args) {
    return ["/usr/bin/timeout", "-k", "1s", String(seconds) + "s", script(name)].concat(args || [])
  }

  function refresh() {
    if (!sourceDir || stopping) return
    if (statusProc.running) { refreshPending = true; return }
    statusProc.running = true
  }

  function selectPort(kind, deviceName, portName) {
    if (!sourceDir || (kind !== "sink" && kind !== "source")) return
    var request = { kind: kind, device: String(deviceName), port: String(portName) }
    if (switchProc.running) { queuedSwitch = request; return }
    switchError = ""
    switchProc.command = bounded(8, "set-port", [request.kind, request.device, request.port])
    switchProc.running = true
  }

  function cyclePort(kind) {
    var devices = kind === "sink" ? sinks : sources
    var device = Model.defaultDevice(devices)
    if (!device || device.ports.length === 0) return ""
    var choices = device.ports.filter(function(p) { return p.availability !== "unavailable" })
    if (choices.length === 0) return ""
    var index = 0
    for (var i = 0; i < choices.length; i++)
      if (choices[i].name === device.activePort) index = (i + 1) % choices.length
    selectPort(kind, device.name, choices[index].name)
    return choices[index].description
  }

  function setOutputVolume(value) {
    if (!hasOutput) return
    defaultSink.audio.volume = Model.clampVolume(value)
  }
  function setInputVolume(value) {
    if (!hasInput) return
    defaultSource.audio.volume = Model.clampVolume(value)
  }
  function toggleOutputMute() { if (hasOutput) defaultSink.audio.muted = !defaultSink.audio.muted }
  function toggleInputMute() { if (hasInput) defaultSource.audio.muted = !defaultSource.audio.muted }

  function startRuntime() {
    if (!sourceDir || eventsProc.running) return
    stopping = false
    restoreProc.running = true
    eventsProc.command = bounded(21600, "audio-events", [])
    eventsProc.running = true
  }

  function stopRuntime() {
    stopping = true
    eventsRestart.stop()
    restoreAgain.stop()
    debounce.stop()
    var procs = [eventsProc, statusProc, switchProc, restoreProc]
    for (var i = 0; i < procs.length; i++) if (procs[i].running) procs[i].running = false
  }

  // The host injects the manifest after creation; start helpers only then.
  onManifestChanged: {
    if (manifest && sourceDir) Qt.callLater(startRuntime)
    else stopRuntime()
  }
  Component.onDestruction: stopRuntime()
  onDefaultSinkChanged: debounce.restart()
  onDefaultSourceChanged: debounce.restart()

  Timer { id: debounce; interval: 150; onTriggered: root.refresh() }
  // Fallback in case the event stream misses something.
  Timer { interval: 15000; repeat: true; running: !root.stopping && !!root.sourceDir; onTriggered: root.refresh() }

  Process {
    id: restoreProc
    command: root.bounded(10, "set-port", ["restore"])
    clearEnvironment: true
    environment: root.childEnvironment
    onExited: {
      // WirePlumber can reapply its own route just after the shell starts;
      // restore once more after it settles.
      if (!root.stopping && !root.restoredTwice) { root.restoredTwice = true; restoreAgain.start() }
      root.refresh()
    }
  }
  property bool restoredTwice: false
  Timer { id: restoreAgain; interval: 3000; onTriggered: if (!root.stopping) restoreProc.running = true }

  Process {
    id: eventsProc
    clearEnvironment: true
    environment: root.childEnvironment
    stdout: SplitParser { onRead: function(line) { if (String(line) === "changed") debounce.restart() } }
    onExited: if (!root.stopping) eventsRestart.restart()
  }
  Timer { id: eventsRestart; interval: 5000; onTriggered: if (!root.stopping) eventsProc.running = true }

  Process {
    id: statusProc
    command: root.bounded(6, "port-status", [])
    clearEnvironment: true
    environment: root.childEnvironment
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
    onExited: function(exitCode) {
      if (root.stopping) return
      if (exitCode === 0) {
        var parsed = Model.parseStatus(statusOut.text)
        root.sinks = parsed.sinks
        root.sources = parsed.sources
        root.statusError = ""
        root.ready = true
        root.revision++
      } else {
        root.statusError = "Could not read audio ports"
      }
      if (root.refreshPending) { root.refreshPending = false; Qt.callLater(root.refresh) }
    }
  }

  Process {
    id: switchProc
    clearEnvironment: true
    environment: root.childEnvironment
    stderr: StdioCollector { id: switchErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (root.stopping) return
      if (exitCode !== 0) root.switchError = String(switchErr.text || "Could not switch audio port").trim()
      var next = root.queuedSwitch
      root.queuedSwitch = null
      if (next) root.selectPort(next.kind, next.device, next.port)
      else root.refresh()
    }
  }

  IpcHandler {
    target: root.pluginId

    function status(): string {
      return JSON.stringify({
        ready: root.ready,
        sink: root.currentSink ? root.currentSink.name : null,
        sinkPort: root.currentSink ? root.currentSink.activePort : null,
        source: root.currentSource ? root.currentSource.name : null,
        sourcePort: root.currentSource ? root.currentSource.activePort : null,
        error: root.error || null
      })
    }
    function cycleOutput(): string { return root.cyclePort("sink") }
    function cycleInput(): string { return root.cyclePort("source") }
    function refresh(): string { root.refresh(); return "refreshing" }
  }
}
