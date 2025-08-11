#!/usr/bin/env bash
# AudioBridge wrapper that uses PulseAudio over IPv4 TCP
set -Eeuo pipefail

DESK_USER="${DESK_USER:-${DEV_USERNAME:-devuser}}"
PULSE_SERVER="${PULSE_SERVER:-tcp:127.0.0.1:4713}"
PULSE_LATENCY_MSEC="${PULSE_LATENCY_MSEC:-180}"
BRIDGE_PATH="${BRIDGE_PATH:-/opt/audio-bridge}"

echo "[wrapper] waiting for PulseAudio on ${PULSE_SERVER}"
for i in {1..120}; do
  if pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1; then
    echo "[wrapper] pulse detected"
    break
  fi
  (( i % 20 == 0 )) && echo "[wrapper] still waiting (${i}s)..."
  sleep 1
done

uid=""
if command -v getent >/dev/null 2>&1; then
  uid="$(getent passwd "$DESK_USER" | cut -d: -f3 || true)"
fi
[ -n "${uid}" ] && export XDG_RUNTIME_DIR="/run/user/${uid}"

echo "[wrapper] starting AudioBridge with PULSE_SERVER=${PULSE_SERVER} (as ${DESK_USER})"
exec su -s /bin/bash "$DESK_USER" -c "exec nice -n -5 env PULSE_SERVER='${PULSE_SERVER}' PULSE_LATENCY_MSEC='${PULSE_LATENCY_MSEC}' XDG_RUNTIME_DIR='${XDG_RUNTIME_DIR:-}' node ${BRIDGE_PATH}/server.js"
