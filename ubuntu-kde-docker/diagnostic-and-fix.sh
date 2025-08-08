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

MAX_ATTEMPTS=${MAX_ATTEMPTS:-5}
RETRY_DELAY=${RETRY_DELAY:-1}

retry() {
  local attempt=1
  while ! "$@"; do
    if [ "$attempt" -ge "$MAX_ATTEMPTS" ]; then
      log WARN "Command '$*' failed after $attempt attempts"
      return 1
    fi
    log WARN "Command '$*' failed (attempt $attempt/$MAX_ATTEMPTS). Retrying in ${RETRY_DELAY}s..."
    attempt=$((attempt + 1))
    sleep "$RETRY_DELAY"
  done
  return 0
}

wait_for_pulseaudio() {
  local attempt=1
  while ! pulseaudio --check >/dev/null 2>&1; do
    if [ "$attempt" -ge "$MAX_ATTEMPTS" ]; then
      log WARN "PulseAudio not responding after $attempt attempts"
      return 1
    fi
    log WARN "PulseAudio not ready (attempt $attempt/$MAX_ATTEMPTS). Retrying in ${RETRY_DELAY}s..."
    attempt=$((attempt + 1))
    sleep "$RETRY_DELAY"
  done
  return 0
}

run_pactl() {
  wait_for_pulseaudio || return 1
  retry pactl "$@"
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
if ! wait_for_pulseaudio; then
  log WARN "PulseAudio is not running. Attempting to start..."
  pulseaudio --start >>"$LOG_FILE" 2>&1 || log ERROR "Failed to start PulseAudio"
  if ! wait_for_pulseaudio; then
    log ERROR "PulseAudio failed to respond after start"
  else
    log INFO "PulseAudio is running."
  fi
else
  log INFO "PulseAudio is running."
fi

# 2. List sinks and sources
log INFO "Listing sinks and sources..."
if ! run_pactl list short sinks | tee -a "$LOG_FILE"; then
  log ERROR "Failed to list sinks"
fi
if ! run_pactl list short sources | tee -a "$LOG_FILE"; then
  log ERROR "Failed to list sources"
fi

DEFAULT_SINK="virtual_speaker"

# 3. Ensure virtual_speaker exists
SINK_TMP=$(mktemp)
if ! run_pactl list short sinks >"$SINK_TMP"; then
  log ERROR "Failed to list sinks"
elif ! grep -q "$DEFAULT_SINK" "$SINK_TMP"; then
  log WARN "$DEFAULT_SINK not found. Creating..."
  if ! run_pactl load-module module-null-sink \
    sink_name="$DEFAULT_SINK" \
    sink_properties=device.description=Virtual_Marketing_Speaker \
    >>"$LOG_FILE" 2>&1; then
    log ERROR "Failed to create $DEFAULT_SINK"
  fi
else
  log INFO "$DEFAULT_SINK exists."
fi
rm -f "$SINK_TMP"

# 4. Set default sink to virtual_speaker and move existing streams
if run_pactl set-default-sink "$DEFAULT_SINK" >>"$LOG_FILE" 2>&1; then
  log INFO "Default sink set to $DEFAULT_SINK"
  INPUT_TMP=$(mktemp)
  if ! run_pactl list short sink-inputs >"$INPUT_TMP"; then
    log ERROR "Failed to list sink inputs"
  else
    awk '{print $1}' "$INPUT_TMP" | while read -r input; do
      if [ -n "$input" ]; then
        run_pactl move-sink-input "$input" "$DEFAULT_SINK" >>"$LOG_FILE" 2>&1 || true
      fi
    done
  fi
  rm -f "$INPUT_TMP"
else
  log ERROR "Failed to set default sink to $DEFAULT_SINK"
fi

# 5. Unmute and set volume to 100%
run_pactl set-sink-mute "$DEFAULT_SINK" 0 >>"$LOG_FILE" 2>&1 || true
run_pactl set-sink-volume "$DEFAULT_SINK" 100% >>"$LOG_FILE" 2>&1 || true

# 6. Restart audio bridge if present
if pgrep -f 'audio-bridge' >/dev/null; then
  log INFO "Restarting audio-bridge..."
  pkill -f 'audio-bridge' || true
  sleep 1
  nohup audio-bridge >>"$LOG_FILE" 2>&1 &
fi

log INFO "Audio diagnostic and fix completed."
