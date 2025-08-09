#!/usr/bin/env bash
set -euo pipefail

PULSE_USER="${PULSE_USER:-${DEV_USERNAME:-devuser}}"
PULSE_UID="${PULSE_UID:-$(id -u "$PULSE_USER" 2>/dev/null || echo 1000)}"
RUNTIME_DIR="/run/user/$PULSE_UID"

echo "Waiting for PulseAudio to be ready for AudioBridge..."
for i in {1..20}; do
  if su - "$PULSE_USER" -c "export XDG_RUNTIME_DIR=$RUNTIME_DIR; pactl info" >/dev/null 2>&1; then
    echo "PulseAudio is ready. Starting AudioBridge."
    exec /usr/bin/node /opt/audio-bridge/webrtc-audio-server.cjs
  fi
  echo "PulseAudio not ready for AudioBridge (attempt $i/20)" >&2
  sleep 1
done

echo "PulseAudio failed to start for AudioBridge" >&2
exit 1

