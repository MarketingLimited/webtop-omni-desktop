#!/usr/bin/env bash
set -euo pipefail

DESK_USER="${1:-devuser}"
export PULSE_SERVER='tcp:127.0.0.1:4713'

say(){ printf '[pulse-daemon] %s\n' "$*"; }

# Wait for initial pulse setup to complete
say "waiting for initial PulseAudio setup"
for i in {1..60}; do
  if pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1; then
    say "initial setup detected"; break
  fi
  sleep 1
done

# Monitor and maintain PulseAudio daemon using pulse-ensure
while true; do
  if ! pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1; then
    say "PulseAudio TCP not responding, restarting"
    /usr/local/bin/pulse-ensure.sh "${DESK_USER}" || true
  fi
  sleep 10
done