#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"

if ! command -v pulseaudio >/dev/null 2>&1; then
  echo "⚠️ pulseaudio not found; skipping startup"
  exit 0
fi

export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
export PULSE_RUNTIME_PATH="${XDG_RUNTIME_DIR}/pulse"
mkdir -p "$PULSE_RUNTIME_PATH"
if id "$DEV_USERNAME" >/dev/null 2>&1; then
  chown "$DEV_USERNAME:$DEV_USERNAME" "$XDG_RUNTIME_DIR" "$PULSE_RUNTIME_PATH" || true
fi

/usr/local/bin/wait-for-dbus.sh
exec /usr/bin/pulseaudio --daemonize=no --disallow-exit --exit-idle-time=-1 --system=false --file="/home/${DEV_USERNAME}/.config/pulse/default.pa"
