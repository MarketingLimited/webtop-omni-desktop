#!/bin/bash
# diagnostic-and-fix.sh: Automatic audio diagnostic and fix script for WebTop container
set -euo pipefail

LOG_FILE="${LOG_FILE:-/tmp/audio_diagnostic.log}"
: >"$LOG_FILE"

log() {
  local level="$1"; shift
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$timestamp] [$level] $*" | tee -a "$LOG_FILE"
}

# Determine development user and runtime directory
DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="$(id -u "$DEV_USERNAME")"
XDG_RUNTIME_DIR="/run/user/$DEV_UID"

run_pulseaudio() {
  su - "$DEV_USERNAME" -c "$*"
}

run_pactl() {
  su - "$DEV_USERNAME" -c "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR pactl $*"
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
run_pulseaudio "pulseaudio --check || pulseaudio --start" >>"$LOG_FILE" 2>&1
for i in {1..10}; do
  if run_pulseaudio "pulseaudio --check" 2>/dev/null || run_pactl info >/dev/null 2>&1; then
    log INFO "PulseAudio started successfully."
    break
  fi
  sleep 1
done
if ! run_pulseaudio "pulseaudio --check" 2>/dev/null && ! run_pactl info >/dev/null 2>&1; then
  log WARN "PulseAudio is still not available after 10 seconds."
fi

# 2. List sinks and sources
log INFO "Listing sinks and sources..."
run_pactl list short sinks | tee -a "$LOG_FILE" || true
run_pactl list short sources | tee -a "$LOG_FILE" || true

DEFAULT_SINK="virtual_speaker"

# 3. Ensure virtual_speaker exists
if ! run_pactl list short sinks | grep -q "$DEFAULT_SINK"; then
  log WARN "$DEFAULT_SINK not found. Creating..."
  run_pactl load-module module-null-sink \
    "sink_name=$DEFAULT_SINK" \
    "sink_properties=device.description=Virtual_Marketing_Speaker" \
    >>"$LOG_FILE" 2>&1 || log ERROR "Failed to create $DEFAULT_SINK"
else
  log INFO "$DEFAULT_SINK exists."
fi

# 4. Set default sink to virtual_speaker and move existing streams
if run_pactl set-default-sink "$DEFAULT_SINK" >>"$LOG_FILE" 2>&1; then
  log INFO "Default sink set to $DEFAULT_SINK"
  run_pactl list short sink-inputs | awk '{print $1}' | while read -r input; do
    if [ -n "$input" ]; then
      run_pactl move-sink-input "$input" "$DEFAULT_SINK" >>"$LOG_FILE" 2>&1 || true
    fi
  done
else
  log ERROR "Failed to set default sink to $DEFAULT_SINK"
fi

# 5. Unmute and set volume to 100%
run_pactl set-sink-mute "$DEFAULT_SINK" 0 >>"$LOG_FILE" 2>&1 || true

# Force volume to 100% and verify
current_volume=""
for i in {1..5}; do
  run_pactl set-sink-volume "$DEFAULT_SINK" 100% >>"$LOG_FILE" 2>&1 || true
  current_volume="$(run_pactl get-sink-volume "$DEFAULT_SINK" 2>/dev/null | awk '/Volume:/ {print $5}')"
  if [ "$current_volume" = "100%" ]; then
    log INFO "Volume confirmed at 100%"
    break
  fi
  sleep 1
done
if [ "$current_volume" != "100%" ]; then
  log WARN "Unable to confirm volume at 100% (current: $current_volume)"
fi

# 6. Restart audio bridge if present
if pgrep -f 'audio-bridge' >/dev/null; then
  log INFO "Restarting audio-bridge..."
  pkill -f 'audio-bridge' || true
  sleep 1
  nohup audio-bridge >>"$LOG_FILE" 2>&1 &
fi

if run_pulseaudio "pulseaudio --check" 2>/dev/null || run_pactl info >/dev/null 2>&1; then
  log INFO "Audio diagnostic and fix completed."
else
  log WARN "Audio diagnostic completed but PulseAudio remains unavailable."
fi

exit 0
