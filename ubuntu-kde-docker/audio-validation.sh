#!/bin/bash
# Simple audio validation for container startup
# Checks PulseAudio via pactl and audio bridge health endpoint
#
# Exit codes:
#   1 - PulseAudio not responding
#   2 - No PulseAudio sinks
#   3 - No PulseAudio sources
#   4 - Audio health endpoint failed

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"
AUDIO_PORT="${AUDIO_PORT:-8080}"

export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
export PULSE_RUNTIME_PATH="${XDG_RUNTIME_DIR}/pulse"

# Verify PulseAudio responds
if ! su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}; pactl info" >/dev/null 2>&1; then
  echo "PulseAudio not responding" >&2
  exit 1
fi

# Ensure at least one sink exists
if ! su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}; pactl list short sinks" | grep -q .; then
  echo "No PulseAudio sinks found" >&2
  exit 2
fi

# Ensure at least one source exists
if ! su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}; pactl list short sources" | grep -q .; then
  echo "No PulseAudio sources found" >&2
  exit 3
fi

# Check audio bridge health endpoint
if ! curl -fsS "http://localhost:${AUDIO_PORT}/health" >/dev/null; then
  echo "Audio service health check failed" >&2
  exit 4
fi

echo "Audio validation passed"
exit 0

