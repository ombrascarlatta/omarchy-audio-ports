# shellcheck shell=bash
# Shared helpers. Sourced by the scripts in this directory; never executed.
export LC_ALL=C

# Resolve a tool from /usr/bin, or from AUDIO_PORTS_TEST_BIN during tests.
tool() {
  local name=$1
  if [[ -n ${AUDIO_PORTS_TEST_BIN:-} ]]; then
    [[ $AUDIO_PORTS_TEST_BIN == /* && -x $AUDIO_PORTS_TEST_BIN/$name ]] || return 1
    printf '%s\n' "$AUDIO_PORTS_TEST_BIN/$name"
  else
    [[ -x /usr/bin/$name ]] || return 1
    printf '%s\n' "/usr/bin/$name"
  fi
}

# shellcheck disable=SC2034 # used by the scripts that source this file
timeout_bin=/usr/bin/timeout
# shellcheck disable=SC2034
head_bin=/usr/bin/head

pactl_path() {
  tool pactl || { echo "Required pactl executable is unavailable" >&2; exit 69; }
}

valid_kind() { [[ $1 == sink || $1 == source ]]; }
# PipeWire/PulseAudio node names and ALSA port names are plain identifiers.
valid_device() { [[ ${#1} -le 256 && $1 =~ ^[A-Za-z0-9_][A-Za-z0-9._:+@-]*$ ]]; }
valid_port() { [[ ${#1} -le 128 && $1 =~ ^[A-Za-z0-9_][A-Za-z0-9._:+@-]*$ ]]; }

state_file() {
  local base=${XDG_STATE_HOME:-$HOME/.local/state}
  [[ $base == /* ]] || base=$HOME/.local/state
  printf '%s\n' "$base/omarchy-audio-ports/ports.tsv"
}
