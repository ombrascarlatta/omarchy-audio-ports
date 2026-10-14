#!/usr/bin/env bash
# Exercises the helper scripts against the fake pactl in tests/fixtures/bin.
set -euo pipefail
plugin=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export AUDIO_PORTS_TEST_BIN=$plugin/tests/fixtures/bin AUDIO_PORTS_TEST_DIR=$work XDG_STATE_HOME=$work/state
cp "$plugin"/tests/fixtures/list-*.txt "$work/"
echo alsa_output.pci-0000_00_1f.3.analog-stereo >"$work/default-sink"
echo alsa_input.pci-0000_00_1f.3.analog-stereo >"$work/default-source"
fail() { echo "integration: $*" >&2; exit 1; }
s=$plugin/scripts

out=$("$s/port-status")
[[ $(grep -c $'^D\t' <<<"$out") == 2 ]] || fail "expected 2 ALSA devices (BT and monitor skipped): $out"
[[ $(grep -c $'^P\tsource\t' <<<"$out") == 3 ]] || fail "expected 3 source ports"
grep -q $'^P\tsink\talsa_output.pci-0000_00_1f.3.analog-stereo\tanalog-output-headphones\tHeadphones\tunknown$' <<<"$out" || fail "unknown sink port missing"
grep -q $'\tHeadphone Mic\tunavailable$' <<<"$out" || fail "unavailable not parsed"
grep -q $'^D\tsource\talsa_input.pci-0000_00_1f.3.analog-stereo\tBuilt-in Audio Analog Stereo\tanalog-input-internal-mic\t1$' <<<"$out" || fail "default source row wrong"

"$s/set-port" source alsa_input.pci-0000_00_1f.3.analog-stereo analog-input-headset-mic >/dev/null
grep -qx 'set-source-port alsa_input.pci-0000_00_1f.3.analog-stereo analog-input-headset-mic' "$work/calls" || fail "port not set"
grep -qx 'set-default-source alsa_input.pci-0000_00_1f.3.analog-stereo' "$work/calls" || fail "default not set"
[[ $(stat -c %a "$work/state/omarchy-audio-ports/ports.tsv") == 600 ]] || fail "state not private"

# Remembering replaces the previous entry for the same device.
"$s/set-port" source alsa_input.pci-0000_00_1f.3.analog-stereo analog-input-internal-mic --keep-default >/dev/null
[[ $(wc -l <"$work/state/omarchy-audio-ports/ports.tsv") == 1 ]] || fail "state not deduplicated"

# Invalid arguments are rejected before pactl runs.
for bad in "sink -x p" "card a b" "sink a;b p" "sink a p --force"; do
  # shellcheck disable=SC2086
  if "$s/set-port" $bad 2>/dev/null; then fail "accepted: $bad"; fi
done

# Cycling skips the unavailable port: internal -> headset -> internal.
: >"$work/calls"
[[ $("$s/cycle-port" source) == "Headset Microphone" ]] || fail "cycle 1"
[[ $("$s/cycle-port" source) == "Internal Microphone" ]] || fail "cycle 2 (should skip unavailable)"
grep -q "Microphone" "$work/notifications" || fail "no notification"
! grep -q set-default "$work/calls" || fail "cycle-port must not change the default"
[[ $("$s/cycle-port" sink --quiet) == "Headphones" ]] || fail "sink cycle"

# Restore reapplies remembered ports only.
: >"$work/calls"
"$s/set-port" restore
grep -q '^set-sink-port alsa_output.pci-0000_00_1f.3.analog-stereo analog-output-headphones$' "$work/calls" || fail "restore"
! grep -q set-default "$work/calls" || fail "restore changed the default"

[[ $(timeout 3 "$s/audio-events") == changed ]] || fail "audio-events"
echo "integration: ok"
