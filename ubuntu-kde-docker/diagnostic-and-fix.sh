#!/bin/bash
# diagnostic-and-fix.sh: Automatic audio diagnostic and fix script for WebTop container
set -euo pipefail

# Assume the user's PulseAudio runtime directory is available
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

LOG_FILE="${LOG_FILE:-/tmp/audio_diagnostic.log}"
: >"$LOG_FILE"

log() {
  local level="$1"; shift
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$timestamp] [$level] $*" | tee -a "$LOG_FILE"
}

# Ensure required commands exist
for cmd in pulseaudio pactl pgrep pkill; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log ERROR "Required command '$cmd' not found"
    exit 1
  fi
done

log INFO "Starting audio diagnostic..."

# 1. Check PulseAudio status
log INFO "Checking PulseAudio status..."
if ! pulseaudio --check 2>/dev/null; then
  log WARN "PulseAudio is not running. Attempting to start..."
  pulseaudio --start >>"$LOG_FILE" 2>&1 || log ERROR "Failed to start PulseAudio"
else
  log INFO "PulseAudio is running."
fi

# 2. List sinks and sources
log INFO "Listing sinks and sources..."
pactl list short sinks | tee -a "$LOG_FILE"
pactl list short sources | tee -a "$LOG_FILE"

DEFAULT_SINK="virtual_speaker"

# 3. Ensure virtual_speaker exists
if ! pactl list short sinks | grep -q "$DEFAULT_SINK"; then
  log WARN "$DEFAULT_SINK not found. Creating..."
  pactl load-module module-null-sink \
    sink_name="$DEFAULT_SINK" \
    sink_properties=device.description=Virtual_Marketing_Speaker \
    >>"$LOG_FILE" 2>&1 || log ERROR "Failed to create $DEFAULT_SINK"
else
  log INFO "$DEFAULT_SINK exists."
fi

# 4. Set default sink to virtual_speaker and move existing streams
if pactl set-default-sink "$DEFAULT_SINK" >>"$LOG_FILE" 2>&1; then
  log INFO "Default sink set to $DEFAULT_SINK"
  pactl list short sink-inputs | awk '{print $1}' | while read -r input; do
    if [ -n "$input" ]; then
      pactl move-sink-input "$input" "$DEFAULT_SINK" >>"$LOG_FILE" 2>&1 || true
    fi
  done
else
  log ERROR "Failed to set default sink to $DEFAULT_SINK"
fi

# 5. Unmute and set volume to 100%
pactl set-sink-mute "$DEFAULT_SINK" 0 >>"$LOG_FILE" 2>&1 || true
pactl set-sink-volume "$DEFAULT_SINK" 100% >>"$LOG_FILE" 2>&1 || true

# 6. Restart audio bridge if present
if pgrep -f 'audio-bridge' >/dev/null; then
  log INFO "Restarting audio-bridge..."
  pkill -f 'audio-bridge' || true
  sleep 1
  nohup audio-bridge >>"$LOG_FILE" 2>&1 &
fi

log INFO "Audio diagnostic and fix completed."
