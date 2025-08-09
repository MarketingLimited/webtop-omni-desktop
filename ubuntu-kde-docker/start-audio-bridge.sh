#!/usr/bin/env bash
set -euo pipefail

PULSE_USER="${PULSE_USER:-${DEV_USERNAME:-devuser}}"
PULSE_UID="${PULSE_UID:-$(id -u "$PULSE_USER" 2>/dev/null || echo 1000)}"
RUNTIME_DIR="/run/user/$PULSE_UID"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Waiting for PulseAudio to be ready for AudioBridge..."
attempt=1
max_attempts=5
sleep_time=1

# Retry until PulseAudio responds, using exponential backoff
while [ "$attempt" -le "$max_attempts" ]; do
  # Test both the Unix socket (via XDG_RUNTIME_DIR) and TCP port 4713
  if su - "$PULSE_USER" -c "export XDG_RUNTIME_DIR=$RUNTIME_DIR; pactl info" >/dev/null 2>&1 || \
     su - "$PULSE_USER" -c "pactl -s tcp:localhost:4713 info" >/dev/null 2>&1; then
    echo "PulseAudio is ready. Starting AudioBridge."
    exec su - "$PULSE_USER" -c "export XDG_RUNTIME_DIR=$RUNTIME_DIR PULSE_RUNTIME_PATH=$RUNTIME_DIR/pulse PULSE_SERVER=unix:$RUNTIME_DIR/pulse/native; node /opt/audio-bridge/webrtc-audio-server.cjs"
  fi

  echo "PulseAudio not ready for AudioBridge (attempt $attempt/$max_attempts)" >&2
  # Fall back to starting PulseAudio before the next attempt
  "$SCRIPT_DIR/start-pulseaudio.sh" >/dev/null 2>&1 || true
  sleep "$sleep_time"
  sleep_time=$((sleep_time * 2))
  attempt=$((attempt + 1))
done

echo "PulseAudio failed to start for AudioBridge" >&2
exit 1

