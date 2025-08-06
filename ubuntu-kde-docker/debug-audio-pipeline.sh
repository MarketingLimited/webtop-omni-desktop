#!/bin/bash
# Debug PipeWire + WebRTC audio pipeline
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

blue "🔍 Audio Pipeline Debug Tool"

# Step 1: PipeWire status
blue "\n📡 Step 1: PipeWire Service"
if pgrep -x pipewire >/dev/null; then
    green "✅ PipeWire process is running"
else
    red "❌ PipeWire process not found"
fi

# Step 2: Virtual devices
blue "\n🔊 Step 2: Virtual Audio Devices"
if pw-cli list-objects Node | grep -q virtual_speaker; then
    green "✅ virtual_speaker node present"
else
    red "❌ virtual_speaker node missing"
fi
if pw-cli list-objects Node | grep -q virtual_microphone; then
    green "✅ virtual_microphone node present"
else
    yellow "⚠️ virtual_microphone node missing"
fi

# Step 3: WebRTC bridge
blue "\n🌐 Step 3: WebRTC Bridge"
if curl -sf http://localhost:8080/package.json | grep -q pipewire-webrtc-bridge; then
    green "✅ WebRTC bridge responding"
else
    red "❌ WebRTC bridge not responding"
fi

blue "\n🎉 Debug complete"
