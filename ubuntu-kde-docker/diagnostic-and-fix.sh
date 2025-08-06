#!/bin/bash
# PipeWire diagnostic and fix script for WebTop container
set -euo pipefail

LOG_FILE="${LOG_FILE:-/tmp/audio_diagnostic.log}"
: >"$LOG_FILE"

log() {
  local level="$1"; shift
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$timestamp] [$level] $*" | tee -a "$LOG_FILE"
}

# Ensure required commands exist
for cmd in pw-cli wpctl pgrep pkill; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log ERROR "Required command '$cmd' not found"
    exit 1
  fi
done

log INFO "Starting audio diagnostic..."

# 1. Check PipeWire status
log INFO "Checking PipeWire status..."
if ! pw-cli info >/dev/null 2>&1; then
  log ERROR "PipeWire is not running"
else
  log INFO "PipeWire is running."
fi

# 2. List nodes
log INFO "Listing PipeWire nodes..."
pw-cli list-objects Node | tee -a "$LOG_FILE"

DEFAULT_SINK="virtual_speaker"

# 3. Ensure virtual_speaker exists
if ! pw-cli list-objects Node | grep -q "$DEFAULT_SINK"; then
  log WARN "$DEFAULT_SINK not found."
else
  log INFO "$DEFAULT_SINK exists."
fi

# 4. Set default sink to virtual_speaker
sink_id=$(pw-cli list-objects Node | awk '/"virtual_speaker"/ {print $1}')
if [ -n "$sink_id" ]; then
  if wpctl set-default "$sink_id" >>"$LOG_FILE" 2>&1; then
    log INFO "Default sink set to $DEFAULT_SINK"
  else
    log ERROR "Failed to set default sink to $DEFAULT_SINK"
  fi
else
  log WARN "Could not determine ID for $DEFAULT_SINK"
fi

log INFO "Audio diagnostic completed."
