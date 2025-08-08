#!/usr/bin/env bash
set -euo pipefail

# This script is designed to be run by supervisord as root.
# It expects PULSE_USER and PULSE_UID to be set in the environment.

if [ -z "${PULSE_USER+x}" ]; then
    echo "PULSE_USER is not set. Exiting." >&2
    exit 1
fi

if [ -z "${PULSE_UID+x}" ]; then
    echo "PULSE_UID is not set. Exiting." >&2
    exit 1
fi

LOGFILE="${PULSE_LOGFILE:-/var/log/supervisor/pulseaudio.log}"

# 1. Confirm required packages are installed
REQUIRED_PKGS=(pulseaudio pulseaudio-utils alsa-utils)
echo "Checking required audio packages..."
for pkg in "${REQUIRED_PKGS[@]}"; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "Missing required package: $pkg" >&2
    exit 1
  fi
done
echo "All required packages are installed."

# 2. Ensure PulseAudio runs with a user who can manage audio devices
if ! id "$PULSE_USER" >/dev/null 2>&1; then
  echo "User $PULSE_USER does not exist" >&2
  exit 1
fi
if ! id -nG "$PULSE_USER" | grep -qw audio; then
  echo "User $PULSE_USER is not in audio group" >&2
  # Add the user to the audio group as a fallback
    usermod -aG audio "$PULSE_USER"
fi

RUNTIME_DIR="/run/user/$PULSE_UID"
PULSE_DIR="$RUNTIME_DIR/pulse"
mkdir -p "$PULSE_DIR"
chown -R "$PULSE_USER:$PULSE_USER" "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR"

# 3. Remove stale PID files or instances
rm -f "$PULSE_DIR"/*.pid 2>/dev/null || true
# Use pkill with the user's UID to avoid killing other processes
pkill -u "$PULSE_UID" pulseaudio >/dev/null 2>&1 || true
sleep 1

# 4. Start PulseAudio in daemon mode and log output
# The command is run via su to ensure it's executed by the correct user.
su - "$PULSE_USER" -c "export XDG_RUNTIME_DIR=$RUNTIME_DIR; pulseaudio -D --log-target=file:$LOGFILE -vv"

# 5. Wait for PulseAudio to start
echo "Waiting for PulseAudio to start..."
for i in {1..15}; do
  if su - "$PULSE_USER" -c "export XDG_RUNTIME_DIR=$RUNTIME_DIR; pactl info" >/dev/null 2>&1; then
    echo "PulseAudio is running."
    break
  fi
  echo "Still waiting for PulseAudio... (attempt $i)"
  sleep 1
done

# 6. Health check for sinks/sources
echo "Performing PulseAudio health check..."
SINKS=$(su - "$PULSE_USER" -c "export XDG_RUNTIME_DIR=$RUNTIME_DIR; pactl list short sinks" 2>/dev/null)
if [ -z "$SINKS" ]; then
  echo "Health check failed: no PulseAudio sinks found" >&2
  # Attempt to load the null sink as a fallback
    su - "$PULSE_USER" -c "export XDG_RUNTIME_DIR=$RUNTIME_DIR; pactl load-module module-null-sink sink_name=fallback_speaker"
    sleep 1
    SINKS=$(su - "$PULSE_USER" -c "export XDG_RUNTIME_DIR=$RUNTIME_DIR; pactl list short sinks" 2>/dev/null)
    if [ -z "$SINKS" ]; then
        echo "Failed to create a fallback sink. Audio will not work." >&2
        exit 1
    fi
fi
echo "Available sinks:"
echo "$SINKS"

echo "PulseAudio is ready."
