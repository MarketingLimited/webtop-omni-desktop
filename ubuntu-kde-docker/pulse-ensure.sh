#!/usr/bin/env bash
# Ensure PulseAudio is running over IPv4 TCP and configure virtual_speaker
set -euo pipefail

DESK_USER="${1:-devuser}"
PULSE_SERVER="${PULSE_SERVER:-tcp:127.0.0.1:4713}"
PRATE="${PULSE_RATE:-48000}"
PFORM="${PULSE_FORMAT:-s16le}"
PCH="${PULSE_CHANNELS:-2}"
NLAT="${NULL_LATENCY_MSEC:-200}"

say(){ printf '[pulse-ensure] %s\n' "$*"; }

# Fresh start for per-user Pulse with TCP
sudo -u "${DESK_USER}" pulseaudio --kill 2>/dev/null || true
if ! pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1; then
  say "starting pulseaudio for ${DESK_USER} (TCP)"
  sudo -u "${DESK_USER}" pulseaudio --daemonize=yes \
    -L 'module-native-protocol-tcp port=4713 listen=127.0.0.1 auth-anonymous=1' \
    --exit-idle-time=-1 --log-target=journal || true
  for i in {1..60}; do
    pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1 && { say 'tcp is up'; break; }
    sleep 1
  done
else
  say "tcp reachable"
fi

# Remove modules that can degrade quality
mods="$(pactl --server="${PULSE_SERVER}" list short modules || true)"
echo "$mods" | awk '/module-suspend-on-idle/ {print $1}' | xargs -r -I{} pactl --server="${PULSE_SERVER}" unload-module {}
echo "$mods" | awk '/module-echo-cancel/ {print $1}'     | xargs -r -I{} pactl --server="${PULSE_SERVER}" unload-module {}

# Ensure a single virtual_speaker with explicit spec and latency
say "ensuring virtual_speaker (${PRATE}Hz ${PFORM} ${PCH}ch, latency_msec=${NLAT})"
sinks="$(pactl --server="${PULSE_SERVER}" list short sinks || true)"
if ! echo "$sinks" | cut -f2 | grep -qx virtual_speaker; then
  pactl --server="${PULSE_SERVER}" load-module module-null-sink \
    sink_name=virtual_speaker rate="${PRATE}" channels="${PCH}" format="${PFORM}" latency_msec="${NLAT}" \
    sink_properties=device.description=Virtual_Speaker >/dev/null
fi

# Set defaults
pactl --server="${PULSE_SERVER}" set-default-sink virtual_speaker || true
if pactl --server="${PULSE_SERVER}" list short sources | awk '{print $2}' | grep -qx virtual_speaker.monitor; then
  pactl --server="${PULSE_SERVER}" set-default-source virtual_speaker.monitor || true
fi

# Unmute and conservative volume
pactl --server="${PULSE_SERVER}" set-sink-mute virtual_speaker 0 || true
pactl --server="${PULSE_SERVER}" set-sink-volume virtual_speaker 70% || true
