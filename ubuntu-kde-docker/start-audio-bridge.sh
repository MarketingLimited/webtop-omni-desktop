#!/usr/bin/env bash
set -euo pipefail

PULSE_USER="${PULSE_USER:-${DEV_USERNAME:-devuser}}"
PULSE_UID="${PULSE_UID:-$(id -u "$PULSE_USER" 2>/dev/null || echo 1000)}"
RUNTIME_DIR="/run/user/$PULSE_UID"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRIDGE_PORT="${WEBRTC_PORT:-${AUDIO_PORT:-8080}}"
PARECORD_DEVICE="${PARECORD_DEVICE:-virtual_speaker.monitor}"

run_as_pulse_user() {
  if [ "$(id -u)" -eq "$PULSE_UID" ]; then
    bash -lc "$1"
  else
    su - "$PULSE_USER" -c "$1"
  fi
}

echo "Waiting for PulseAudio to be ready for AudioBridge..."
attempt=1
max_attempts=5
sleep_time=1

while [ "$attempt" -le "$max_attempts" ]; do
  if run_as_pulse_user "export XDG_RUNTIME_DIR=$RUNTIME_DIR; pactl info" >/dev/null 2>&1; then
    echo "PulseAudio is ready on UNIX socket. Starting AudioBridge."
    run_as_pulse_user "export XDG_RUNTIME_DIR=$RUNTIME_DIR PULSE_RUNTIME_PATH=$RUNTIME_DIR/pulse PULSE_SERVER=unix:$RUNTIME_DIR/pulse/native WEBRTC_PORT=$BRIDGE_PORT PARECORD_DEVICE=$PARECORD_DEVICE; exec node /opt/audio-bridge/webrtc-audio-server.cjs"
  elif run_as_pulse_user "pactl -s tcp:localhost:4713 info" >/dev/null 2>&1; then
    echo "PulseAudio is ready over TCP. Starting AudioBridge."
    run_as_pulse_user "PULSE_SERVER=tcp:127.0.0.1:4713 WEBRTC_PORT=$BRIDGE_PORT PARECORD_DEVICE=$PARECORD_DEVICE exec node /opt/audio-bridge/webrtc-audio-server.cjs"
  fi

  echo "PulseAudio not ready for AudioBridge (attempt $attempt/$max_attempts)" >&2
  "$SCRIPT_DIR/start-pulseaudio.sh" >/dev/null 2>&1 || true
  sleep "$sleep_time"
  sleep_time=$((sleep_time * 2))
  attempt=$((attempt + 1))
done

echo "PulseAudio failed to start for AudioBridge" >&2
exit 1
