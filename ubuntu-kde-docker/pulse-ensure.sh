#!/usr/bin/env bash
set -euo pipefail
DESK_USER="${1:-devuser}"
export PULSE_SERVER='tcp:127.0.0.1:4713'
say(){ printf '[pulse-ensure] %s\n' "$*"; }

# Start or verify per-user Pulse with TCP
if pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1; then
  say "tcp reachable"
else
  say "starting pulseaudio for ${DESK_USER} with TCP"
  sudo -u "${DESK_USER}" pulseaudio --kill 2>/dev/null || true
  sudo -u "${DESK_USER}" pulseaudio --daemonize=yes \
    -L 'module-native-protocol-tcp port=4713 listen=127.0.0.1 auth-anonymous=1' \
    --exit-idle-time=-1 --log-target=journal || true
  for i in {1..30}; do pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1 && { say 'tcp is up'; break; }; sleep 1; done
fi

# Ensure virtual devices and defaults
say "ensuring virtual devices (no duplicates)"
sinks="$(pactl --server="${PULSE_SERVER}" list short sinks || true)"
sources="$(pactl --server="${PULSE_SERVER}" list short sources || true)"
echo "$sinks"   | cut -f2 | grep -qx virtual_speaker     || pactl --server="${PULSE_SERVER}" load-module module-null-sink     sink_name=virtual_speaker     sink_properties=device.description=Virtual_Marketing_Speaker >/dev/null
echo "$sinks"   | cut -f2 | grep -qx virtual_microphone  || pactl --server="${PULSE_SERVER}" load-module module-null-sink     sink_name=virtual_microphone  sink_properties=device.description=Virtual_Marketing_Microphone >/dev/null
echo "$sources" | cut -f2 | grep -qx virtual_mic_source  || pactl --server="${PULSE_SERVER}" load-module module-virtual-source source_name=virtual_mic_source master=virtual_microphone.monitor >/dev/null
pactl --server="${PULSE_SERVER}" set-default-sink   virtual_speaker    || true
pactl --server="${PULSE_SERVER}" set-default-source virtual_mic_source || true

# Convenience: unmute & set volume
pactl --server="${PULSE_SERVER}" set-sink-mute virtual_speaker 0 || true
pactl --server="${PULSE_SERVER}" set-sink-volume virtual_speaker 100% || true