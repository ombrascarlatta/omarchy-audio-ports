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
  while the microphone is muted; scroll over it to change output volume
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
- IPC: `qs ipc call maxime.audio-ports cycleInput|cycleOutput|status|refresh`

## Install

From git:

```bash
omarchy plugin add https://github.com/OWNER/omarchy-audio-ports.git
omarchy plugin enable maxime.audio-ports
```

From a local checkout, copy (or clone) it to the plugin directory and enable
it:

```bash
cp -r omarchy-audio-ports ~/.config/omarchy/plugins/maxime.audio-ports
omarchy plugin enable maxime.audio-ports
```

Omarchy plugins run unsandboxed inside the shell. Review the code before
enabling it.

After updating the files of an installed plugin by hand, run
`omarchy-restart-shell`: the running shell can keep the previously compiled
panel components even after `omarchy plugin disable`/`enable`.

Remove with `omarchy plugin remove maxime.audio-ports`. The remembered ports
live in `~/.local/state/omarchy-audio-ports/ports.tsv`; delete it to forget them.

## Keyboard shortcut for the microphone

Add to `~/.config/hypr/bindings.conf`:

```
bindd = SUPER ALT, M, Toggle microphone port, exec, ~/.config/omarchy/plugins/maxime.audio-ports/scripts/cycle-port source
bindd = SUPER ALT, A, Toggle output port, exec, ~/.config/omarchy/plugins/maxime.audio-ports/scripts/cycle-port sink
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
