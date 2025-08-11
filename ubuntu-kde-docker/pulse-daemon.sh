#!/usr/bin/env bash
set -euo pipefail

DESK_USER="${1:-devuser}"
export PULSE_SERVER='tcp:127.0.0.1:4713'

say(){ printf '[pulse-daemon] %s\n' "$*"; }

# Wait for initial pulse setup to complete
say "waiting for initial PulseAudio setup"
for i in {1..60}; do
  if pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1; then
    say "initial setup detected"; break
  fi
  sleep 1
done

# Monitor and maintain PulseAudio daemon
while true; do
  if ! pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1; then
    say "PulseAudio TCP not responding, restarting"
    
    # Kill any existing PulseAudio processes
    sudo -u "${DESK_USER}" pulseaudio --kill 2>/dev/null || true
    sleep 2
    
    # Start PulseAudio with TCP module
    sudo -u "${DESK_USER}" pulseaudio --daemonize=yes \
      -L 'module-native-protocol-tcp port=4713 listen=127.0.0.1 auth-anonymous=1' \
      --exit-idle-time=-1 --log-target=journal || true
    
    # Wait for startup
    for i in {1..30}; do 
      pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1 && { say 'tcp restarted'; break; }
      sleep 1
    done
    
    # Recreate virtual devices if needed
    if pactl --server="${PULSE_SERVER}" info >/dev/null 2>&1; then
      sinks="$(pactl --server="${PULSE_SERVER}" list short sinks || true)"
      sources="$(pactl --server="${PULSE_SERVER}" list short sources || true)"
      
      echo "$sinks" | cut -f2 | grep -qx virtual_speaker || {
        pactl --server="${PULSE_SERVER}" load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description=Virtual_Marketing_Speaker >/dev/null || true
      }
      echo "$sinks" | cut -f2 | grep -qx virtual_microphone || {
        pactl --server="${PULSE_SERVER}" load-module module-null-sink sink_name=virtual_microphone sink_properties=device.description=Virtual_Marketing_Microphone >/dev/null || true
      }
      echo "$sources" | cut -f2 | grep -qx virtual_mic_source || {
        pactl --server="${PULSE_SERVER}" load-module module-virtual-source source_name=virtual_mic_source master=virtual_microphone.monitor >/dev/null || true
      }
      
      pactl --server="${PULSE_SERVER}" set-default-sink virtual_speaker || true
      pactl --server="${PULSE_SERVER}" set-default-source virtual_mic_source || true
      pactl --server="${PULSE_SERVER}" set-sink-mute virtual_speaker 0 || true
      pactl --server="${PULSE_SERVER}" set-sink-volume virtual_speaker 100% || true
    fi
  fi
  
  sleep 10
done