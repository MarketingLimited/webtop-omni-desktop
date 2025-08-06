#!/bin/bash
set -euo pipefail

# This script is responsible for starting the user-specific D-Bus session
# and then launching the audio services (PipeWire, WirePlumber, and PipeWire-Pulse)
# that depend on it.

# Environment variables are passed from supervisord.
# DEV_USERNAME, DEV_UID, XDG_RUNTIME_DIR

log() {
    echo "[start-audio-session] $1"
}

log "Initializing audio session for user $DEV_USERNAME (UID: $DEV_UID)..."

# Ensure the XDG_RUNTIME_DIR exists and has the correct permissions
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    log "Creating XDG_RUNTIME_DIR at $XDG_RUNTIME_DIR..."
    mkdir -p "$XDG_RUNTIME_DIR"
    chown "$DEV_UID:$DEV_GID" "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
fi

# Start a user D-Bus session
log "Launching D-Bus user session..."
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
dbus-daemon --session --address=$DBUS_SESSION_BUS_ADDRESS --nofork --nopidfile --syslog-only &
DBUS_PID=$!
log "D-Bus daemon started with PID $DBUS_PID."

# Wait for the D-Bus socket to be available
while [ ! -S "${XDG_RUNTIME_DIR}/bus" ]; do
    log "Waiting for D-Bus socket to be created..."
    sleep 1
done
log "D-Bus socket is available."

# Launch PipeWire
log "Starting PipeWire..."
pipewire &
PIPEWIRE_PID=$!
log "PipeWire started with PID $PIPEWIRE_PID."

# Launch WirePlumber
log "Starting WirePlumber..."
wireplumber &
WIREPLUMBER_PID=$!
log "WirePlumber started with PID $WIREPLUMBER_PID."

# Launch PipeWire-Pulse
log "Starting PipeWire-Pulse..."
pipewire-pulse &
PULSE_PID=$!
log "PipeWire-Pulse started with PID $PULSE_PID."

log "Audio session initialization complete."

# Wait for all background processes to exit
wait $DBUS_PID $PIPEWIRE_PID $WIREPLUMBER_PID $PULSE_PID
