#!/bin/bash
set -euo pipefail

echo "🎧 Testing PipeWire + WebRTC audio pipeline..."

if pw-cli info >/dev/null 2>&1; then
    echo "✅ PipeWire is running"
else
    echo "❌ PipeWire is not running"
    exit 1
fi

if pw-cli list-objects | grep -q virtual_speaker; then
    echo "✅ virtual_speaker device present"
else
    echo "⚠️ virtual_speaker device missing"
fi

if curl -sf http://localhost:8080/package.json | grep -q pipewire-webrtc-bridge; then
    echo "✅ WebRTC bridge responding"
else
    echo "❌ WebRTC bridge not responding"
    exit 1
fi

echo "🎉 Audio pipeline test completed"
