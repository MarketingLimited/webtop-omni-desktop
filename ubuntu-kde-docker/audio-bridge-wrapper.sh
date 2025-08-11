#!/usr/bin/env bash
set -euo pipefail
export PULSE_SERVER='tcp:127.0.0.1:4713'
export PULSE_LATENCY_MSEC='60'

echo "[wrapper] waiting for PulseAudio on ${PULSE_SERVER}"
for i in {1..90}; do
  if pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1; then
    echo "[wrapper] pulse detected"; break
  fi
  (( i % 15 == 0 )) && echo "[wrapper] still waiting (${i}s)..."
  sleep 1
done

uid=""
if command -v getent >/dev/null 2>&1; then uid="$(getent passwd devuser | cut -d: -f3 || true)"; fi
[ -n "${uid}" ] && export XDG_RUNTIME_DIR="/run/user/${uid}"

echo "[wrapper] starting AudioBridge with PULSE_SERVER=${PULSE_SERVER} (as devuser)"
exec su -s /bin/bash devuser -c "env PULSE_SERVER=\"${PULSE_SERVER}\" XDG_RUNTIME_DIR=\"${XDG_RUNTIME_DIR:-}\" node /opt/audio-bridge/server.js"