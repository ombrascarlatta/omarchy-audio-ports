# Audio Ports for Omarchy

Pick the **port** of your sound card (Speakers or Headphones, Internal or
Headset Microphone) straight from the Omarchy bar.

Many laptops expose speakers, the headphone jack and the microphones as ports
of a single ALSA device. When the combo jack cannot detect what is plugged in,
every port reports *availability unknown* and the built-in audio widget offers
no way to switch. Audio Ports lists every port of every ALSA sink and source,
including undetected ones, and switches with one click or one key.

## Features

- Bar icon: a single volume glyph (low/medium/high/muted), highlighted
  while the microphone is muted. Like the built-in Audio widget: left click
  opens the panel, right click toggles output mute, scroll changes output
  volume by 5% per notch (clamped, unmutes). Its tooltip is the plugin's own copy of the bar
  tooltip, so it stays open and updates live while scrolling
- Panel lists every port of every ALSA sink and source, with availability
  (`plugged in`, `unplugged`, `not detected`)
- Click (or Enter) a port to switch to it and make its device the default
- Live microphone peak meter (dBFS) with good-speech and clipping zones and
  peak hold; it captures only while the panel is open
- Output and input volume sliders, mute buttons (or right-click a slider)
- Omarchy-style keyboard navigation (`?` in the panel shows the shortcuts)
- Remembers the last chosen port per device and reapplies it at startup
  (ports only; the default device is never changed on startup)
- `scripts/cycle-port` CLI for Hyprland keybinds, with a notification
- IPC: `omarchy-shell ombrascarlatta.audio-ports <cycleInput|cycleOutput|volumeUp|volumeDown|toggleMute|status|refresh>`

## Requirements

- Omarchy 4 (Quickshell-based shell) with its plugin system
- PipeWire with `pipewire-pulse` (the plugin uses `pactl` from `libpulse`)
- Standard tools: `bash`, `awk`, `timeout` (coreutils)
- Optional: `notify-send` (`libnotify`) for `cycle-port` notifications,
  `logger` (util-linux) for the journal audit lines

All of these ship with a default Omarchy install.

## Install

From git:

```bash
omarchy plugin add https://github.com/ombrascarlatta/omarchy-audio-ports.git
omarchy plugin enable ombrascarlatta.audio-ports
```

For development, clone it into the plugin directory instead:

```bash
git clone https://github.com/ombrascarlatta/omarchy-audio-ports.git \
  ~/.config/omarchy/plugins/ombrascarlatta.audio-ports
omarchy plugin enable ombrascarlatta.audio-ports
```

Omarchy plugins run unsandboxed inside the shell. Review the code before
enabling it.

After updating the files of an installed plugin by hand, run
`omarchy-restart-shell`: the running shell can keep the previously compiled
panel components even after `omarchy plugin disable`/`enable`.

## What it changes on your system

Audio Ports never edits your Omarchy configuration (`shell.json`, bar layout)
or other plugins. Omarchy adds the widget to the bar when you enable it. The
plugin only changes audio state when you ask it to (selecting a port, volume,
mute), and at startup it reapplies the ports you chose before. Your choices are
kept in `~/.local/state/omarchy-audio-ports/ports.tsv`.

The built-in Audio widget stays enabled. If you want only one audio icon, you
can disable it yourself (optional, reversible):

```bash
omarchy plugin disable omarchy.audio
```

## Remove

```bash
omarchy plugin remove ombrascarlatta.audio-ports
rm -rf ~/.local/state/omarchy-audio-ports   # optional: forget remembered ports
omarchy plugin enable omarchy.audio         # if you had disabled the built-in widget
```

Also delete any `cycle-port` keybinds you added to `~/.config/hypr/bindings.conf`.

## Keyboard shortcut for the microphone

Add to `~/.config/hypr/bindings.conf`:

```
bindd = SUPER ALT, M, Toggle microphone port, exec, ~/.config/omarchy/plugins/ombrascarlatta.audio-ports/scripts/cycle-port source
bindd = SUPER ALT, A, Toggle output port, exec, ~/.config/omarchy/plugins/ombrascarlatta.audio-ports/scripts/cycle-port sink
```

`cycle-port` moves the default device to its next port, skipping ports that
report *unplugged*, and shows a notification. It does not change which device
is the default.

## Panel shortcuts

| Key | Action |
| --- | --- |
| J/K, ↑/↓ | Move between sliders and ports |
| Enter/Space | Select port (on a slider: toggle mute) |
| H/L, ←/→ | Volume of the current section |
| M | Mute the current section |
| O / I | Next output / input port |
| ? | Show shortcuts |
| Esc | Close |

## Using it with Audio Priority

[Audio Priority](https://github.com/melonamin/omarchy-audio-priority) already
splits *output* ports into separate devices but not microphone ports. Both
plugins can be enabled together. If Audio Priority is in an automatic mode it
may react when Audio Ports switches the output port (it sees a different
device); use its Custom mode, or use Audio Ports only for microphones.

## Safety

- No network access, no root, no daemons, no systemd units
- Helpers in `scripts/` run with a cleared environment, fixed `/usr/bin`
  tools and `timeout` limits; arguments are validated against a strict
  character set; parsed output is size-bounded
- Device text never reaches the shell: the event stream only emits the fixed
  token `changed`

## Development

```bash
tests/run   # Node model tests + helper integration tests with a fake pactl
```

Requires `node` and `bash`. The QML has not been covered by automated tests.

## License

MIT
