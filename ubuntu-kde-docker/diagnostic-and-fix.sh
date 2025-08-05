#!/bin/bash
# diagnostic-and-fix.sh: Automatic audio diagnostic and fix script for WebTop container
set -e

LOG_FILE="/tmp/audio_diagnostic.log"
echo "[INFO] Starting audio diagnostic..." | tee "$LOG_FILE"

# 1. Check PulseAudio status
echo "[INFO] Checking PulseAudio status..." | tee -a "$LOG_FILE"
if ! pulseaudio --check 2>/dev/null; then
  echo "[WARN] PulseAudio is not running. Starting PulseAudio..." | tee -a "$LOG_FILE"
  pulseaudio --start
else
  echo "[INFO] PulseAudio is running." | tee -a "$LOG_FILE"
fi

# 2. List sinks and sources
echo "[INFO] Listing sinks and sources..." | tee -a "$LOG_FILE"
pactl list short sinks | tee -a "$LOG_FILE"
pactl list short sources | tee -a "$LOG_FILE"

# 3. Ensure virtual_speaker exists
if ! pactl list short sinks | grep -q 'virtual_speaker'; then
  echo "[WARN] virtual_speaker not found. Creating..." | tee -a "$LOG_FILE"
  pactl load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description=Virtual_Marketing_Speaker
else
  echo "[INFO] virtual_speaker exists." | tee -a "$LOG_FILE"
fi

# 4. Set default sink to virtual_speaker
pactl set-default-sink virtual_speaker

# 5. Unmute and set volume to 100%
pactl set-sink-mute virtual_speaker 0
pactl set-sink-volume virtual_speaker 100%

# 6. Restart audio bridge if present
if pgrep -f 'audio-bridge'; then
  echo "[INFO] Restarting audio-bridge..." | tee -a "$LOG_FILE"
  pkill -f 'audio-bridge'
  sleep 1
  nohup audio-bridge &
fi

echo "[INFO] Audio diagnostic and fix completed." | tee -a "$LOG_FILE"
