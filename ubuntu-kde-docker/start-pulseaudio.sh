#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
if id "$DEV_USERNAME" >/dev/null 2>&1; then
  DEV_UID="$(id -u "$DEV_USERNAME")"
else
  DEV_UID="${DEV_UID:-1000}"
fi

if ! command -v pulseaudio >/dev/null 2>&1; then
  echo "⚠️ pulseaudio not found; skipping startup"
  exit 0
fi

XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
PULSE_RUNTIME_PATH="${XDG_RUNTIME_DIR}/pulse"

# Ensure runtime directory exists and has correct permissions
mkdir -p "$PULSE_RUNTIME_PATH"
chown -R "${DEV_UID}:${DEV_UID}" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Warn if audio devices are missing
if [ ! -d /dev/snd ]; then
  echo "⚠️ /dev/snd not found; audio devices may be unavailable. Did you run the container with --device /dev/snd?"
fi

# Wait for D-Bus if helper script is available
if [ -x /usr/local/bin/wait-for-dbus.sh ]; then
  /usr/local/bin/wait-for-dbus.sh
fi

# Run PulseAudio as the development user with the proper environment
exec runuser -u "$DEV_USERNAME" -- env \
  HOME="/home/${DEV_USERNAME}" \
  USER="$DEV_USERNAME" \
  XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
  PULSE_RUNTIME_PATH="$PULSE_RUNTIME_PATH" \
  pulseaudio --daemonize=no --disallow-exit --exit-idle-time=-1 --system=false \
  --file="/home/${DEV_USERNAME}/.config/pulse/default.pa"
