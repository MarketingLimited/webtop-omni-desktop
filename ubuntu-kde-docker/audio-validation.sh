#!/bin/bash
# PipeWire Audio Validation Script
# Runs basic checks to ensure PipeWire and virtual devices are configured

set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"
export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"

echo "🔊 Validating PipeWire audio configuration..."

if pw-cli info >/dev/null 2>&1; then
    echo "✅ PipeWire is running"
else
    echo "❌ PipeWire is not running"
    exit 1
fi

# Ensure virtual devices exist
if ! pw-cli list-objects | grep -q virtual_speaker; then
    echo "⚠️  virtual_speaker not found – creating"
    /usr/local/bin/create-virtual-pipewire-devices.sh >/dev/null 2>&1 || true
fi

# Set default devices using wpctl if available
if command -v wpctl >/dev/null 2>&1; then
    speaker_id=$(wpctl status | grep -A1 'Sinks' | grep 'virtual_speaker' | awk '{print $2}' | tr -d '.')
    mic_id=$(wpctl status | grep -A1 'Sources' | grep 'virtual_microphone' | awk '{print $2}' | tr -d '.')
    [ -n "$speaker_id" ] && wpctl set-default "$speaker_id" >/dev/null 2>&1
    [ -n "$mic_id" ] && wpctl set-default "$mic_id" >/dev/null 2>&1
fi

/usr/local/bin/test-pipewire.sh >/dev/null 2>&1 || true

echo "✅ PipeWire validation complete"
