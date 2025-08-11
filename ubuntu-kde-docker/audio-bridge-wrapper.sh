#!/usr/bin/env bash
set -Eeuo pipefail
DESK_USER="${DESK_USER:-${DEV_USERNAME:-devuser}}"

uid="$(getent passwd "$DESK_USER" | cut -d: -f3 || true)"
[ -n "${uid}" ] || { echo "[wrapper] user not found: $DESK_USER"; exit 1; }

export XDG_RUNTIME_DIR="/run/user/${uid}"
export HOME="/home/${DESK_USER}"
export PULSE_SERVER="unix:${XDG_RUNTIME_DIR}/pulse/native"
export PULSE_LATENCY_MSEC="${PULSE_LATENCY_MSEC:-180}"

echo "[wrapper] waiting for PulseAudio on ${PULSE_SERVER} (user=${DESK_USER})"
for i in {1..120}; do
  if su -s /bin/bash "$DESK_USER" -c "PULSE_SERVER='$PULSE_SERVER' pactl info" >/dev/null 2>&1; then
    break
  fi
  (( i % 20 == 0 )) && echo "[wrapper] still waiting (${i}s)..."
  sleep 1
done

echo "[wrapper] starting AudioBridge as ${DESK_USER}"
exec su -s /bin/bash "$DESK_USER" -c "exec env \
  XDG_RUNTIME_DIR='${XDG_RUNTIME_DIR}' \
  HOME='${HOME}' \
  PULSE_SERVER='${PULSE_SERVER}' \
  PULSE_LATENCY_MSEC='${PULSE_LATENCY_MSEC}' \
  node /opt/audio-bridge/server.js"
