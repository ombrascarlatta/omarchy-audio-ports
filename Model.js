// Pure helpers shared by Service.qml, Panel.qml and the Node tests.
var MAX_DEVICES = 32
var MAX_PORTS = 16

// Parses the TSV emitted by scripts/port-status into
// { sinks: [device], sources: [device] } where device is
// { kind, name, description, activePort, isDefault, ports: [{ name, description, availability }] }.
function parseStatus(text) {
  var result = { sinks: [], sources: [] }
  var byKey = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var cols = lines[i].split("\t")
    if (cols[0] === "D" && cols.length >= 6) {
      var list = cols[1] === "sink" ? result.sinks : (cols[1] === "source" ? result.sources : null)
      if (!list || list.length >= MAX_DEVICES) continue
      var device = {
        kind: cols[1], name: cols[2], description: cols[3] || cols[2],
        activePort: cols[4], isDefault: cols[5] === "1", ports: []
      }
      list.push(device)
      byKey[cols[1] + "\t" + cols[2]] = device
    } else if (cols[0] === "P" && cols.length >= 6) {
      var owner = byKey[cols[1] + "\t" + cols[2]]
      if (!owner || owner.ports.length >= MAX_PORTS) continue
      owner.ports.push({ name: cols[3], description: cols[4] || cols[3], availability: cols[5] })
    }
  }
  return result
}

function defaultDevice(devices) {
  for (var i = 0; i < devices.length; i++) if (devices[i].isDefault) return devices[i]
  return null
}

function activePort(device) {
  if (!device) return null
  for (var i = 0; i < device.ports.length; i++)
    if (device.ports[i].name === device.activePort) return device.ports[i]
  return null
}

// Classifies a port for its glyph.
function portKind(port) {
  var n = String(port && port.name || "").toLowerCase()
  if (n.indexOf("headset") !== -1) return "headset"
  if (n.indexOf("headphone") !== -1) return "headphones"
  if (n.indexOf("hdmi") !== -1 || n.indexOf("iec958") !== -1) return "hdmi"
  if (n.indexOf("speaker") !== -1) return "speaker"
  if (n.indexOf("mic") !== -1 || n.indexOf("input") !== -1) return "mic"
  return "other"
}

function portGlyph(kind, port) {
  var k = portKind(port)
  if (kind === "source") return k === "headset" || k === "headphones" ? "󰋎" : "󰍬"
  if (k === "headphones" || k === "headset") return "󰋋"
  if (k === "hdmi") return "󰡁"
  return "󰓃"
}

function availabilityLabel(port) {
  if (!port) return ""
  if (port.availability === "available") return "plugged in"
  if (port.availability === "unavailable") return "unplugged"
  return "not detected"
}

function rowId(kind, deviceName, portName) {
  return "port:" + kind + ":" + deviceName + "#" + portName
}

// Flat, ordered list of keyboard targets for the panel.
function buildTargets(sinks, sources) {
  var targets = [{ id: "output-volume", kind: "volume", direction: "sink" }]
  function add(kind, devices) {
    for (var i = 0; i < devices.length; i++)
      for (var j = 0; j < devices[i].ports.length; j++)
        targets.push({ id: rowId(kind, devices[i].name, devices[i].ports[j].name),
          kind: "port", direction: kind, device: devices[i], port: devices[i].ports[j] })
  }
  add("sink", sinks || [])
  targets.push({ id: "input-volume", kind: "volume", direction: "source" })
  add("source", sources || [])
  return targets
}

function indexOfId(targets, id) {
  for (var i = 0; i < targets.length; i++) if (targets[i].id === id) return i
  return -1
}

function move(targets, id, delta) {
  if (targets.length === 0) return ""
  var index = indexOfId(targets, id)
  if (index < 0) return targets[0].id
  return targets[Math.max(0, Math.min(targets.length - 1, index + delta))].id
}

function clampVolume(value) {
  var v = Number(value)
  if (!isFinite(v)) return 0
  return Math.max(0, Math.min(1, v))
}

// Microphone meter: linear peak (0..1) -> dBFS, and a -60..0 dB display scale.
var METER_FLOOR_DB = -60
var GOOD_LOW_DB = -18
var GOOD_HIGH_DB = -6
var CLIP_DB = -3

// Quickshell's PwNodePeakMonitor.peak is the cube root of the linear sample
// peak (a "visual" curve), so dBFS = 20*log10(peak^3) = 60*log10(peak).
function peakToDb(peak) {
  var p = Number(peak)
  if (!isFinite(p) || p <= 0) return -Infinity
  return 60 * Math.log(Math.min(1, p)) / Math.LN10
}

function dbToFraction(db) {
  if (!isFinite(db)) return 0
  return Math.max(0, Math.min(1, (db - METER_FLOOR_DB) / -METER_FLOOR_DB))
}

function levelZone(db) {
  if (db >= CLIP_DB) return "clip"
  if (db > GOOD_HIGH_DB) return "hot"
  if (db >= GOOD_LOW_DB) return "good"
  return "low"
}

if (typeof module !== "undefined") module.exports = {
  parseStatus: parseStatus, defaultDevice: defaultDevice, activePort: activePort,
  portKind: portKind, portGlyph: portGlyph, availabilityLabel: availabilityLabel,
  rowId: rowId, buildTargets: buildTargets, indexOfId: indexOfId, move: move,
  clampVolume: clampVolume, peakToDb: peakToDb, dbToFraction: dbToFraction, levelZone: levelZone,
  GOOD_LOW_DB: GOOD_LOW_DB, GOOD_HIGH_DB: GOOD_HIGH_DB, CLIP_DB: CLIP_DB, MAX_DEVICES: MAX_DEVICES, MAX_PORTS: MAX_PORTS
}
