#!/usr/bin/env bash
set -euo pipefail

PULSE_USER="${PULSE_USER:-${DEV_USERNAME:-devuser}}"
PULSE_UID="${PULSE_UID:-$(id -u "$PULSE_USER" 2>/dev/null || echo 1000)}"
LOGFILE="${PULSE_LOGFILE:-/var/log/pulseaudio-startup.log}"

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
  exit 1
fi

RUNTIME_DIR="/run/user/$PULSE_UID"
PULSE_DIR="$RUNTIME_DIR/pulse"
mkdir -p "$PULSE_DIR"
chown -R "$PULSE_USER:$PULSE_USER" "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR"

# 3. Remove stale PID files or instances
rm -f "$PULSE_DIR"/*.pid 2>/dev/null || true
pkill -u "$PULSE_UID" pulseaudio >/dev/null 2>&1 || true

# 4. Start PulseAudio in daemon mode and log output
su - "$PULSE_USER" -c "export XDG_RUNTIME_DIR=$RUNTIME_DIR; pulseaudio -D --log-target=file:$LOGFILE"

for i in {1..10}; do
  if grep -q 'Daemon startup complete' "$LOGFILE" || grep -q 'READY=1' "$LOGFILE"; then
    echo "PulseAudio reported successful startup."
    break
  fi
  sleep 1
done

if ! grep -q 'Daemon startup complete' "$LOGFILE" && ! grep -q 'READY=1' "$LOGFILE"; then
  echo "PulseAudio log does not show successful startup" >&2
  exit 1
fi

# 5. Wait for pactl to report server info
echo "Waiting for PulseAudio availability..."
for i in {1..20}; do
  if su - "$PULSE_USER" -c "export XDG_RUNTIME_DIR=$RUNTIME_DIR; pactl info" >/dev/null 2>&1; then
    echo "pactl info succeeded."
    break
  fi
  echo "PulseAudio not ready (attempt $i/20)" >&2
  sleep 1
done

if ! su - "$PULSE_USER" -c "export XDG_RUNTIME_DIR=$RUNTIME_DIR; pactl info" >/dev/null 2>&1; then
  echo "Failed to connect to PulseAudio with pactl info" >&2
  echo "Check $LOGFILE for details" >&2
  exit 1
fi

# 6. Health check for sinks/sources
echo "Performing PulseAudio health check..."
SINKS=$(su - "$PULSE_USER" -c "export XDG_RUNTIME_DIR=$RUNTIME_DIR; pactl list short sinks" 2>/dev/null)
if [ -z "$SINKS" ]; then
  echo "Health check failed: no PulseAudio sinks found" >&2
  exit 1
fi
echo "$SINKS"

echo "PulseAudio is ready."
