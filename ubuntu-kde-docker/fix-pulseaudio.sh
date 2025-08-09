#!/usr/bin/env bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"
RUNTIME_DIR="/run/user/$DEV_UID"
PULSE_DIR="$RUNTIME_DIR/pulse"

echo "Fixing PulseAudio socket issues..."

# 1. Stop any running PulseAudio instances
pkill -u "$DEV_UID" pulseaudio || true
sleep 2

# 2. Clean up any stale PulseAudio files
rm -rf "$PULSE_DIR"/* || true
rm -f "/home/$DEV_USERNAME/.config/pulse/cookie" || true

# 3. Recreate the directory structure with proper permissions
mkdir -p "$PULSE_DIR"
chown -R "$DEV_USERNAME:$DEV_USERNAME" "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR"

# 4. Start PulseAudio in user mode
su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR=$RUNTIME_DIR PULSE_RUNTIME_PATH=$PULSE_DIR; pulseaudio --daemonize --exit-idle-time=-1"

# 5. Wait for PulseAudio to be ready
echo "Waiting for PulseAudio to start..."
for i in {1..10}; do
  if su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR=$RUNTIME_DIR; pactl info" >/dev/null 2>&1; then
    echo "PulseAudio started successfully"
    exit 0
  fi
  sleep 1
done

echo "Failed to start PulseAudio"
exit 1
