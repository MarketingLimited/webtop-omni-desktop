#!/bin/bash
set -euo pipefail

echo "🔍 Running comprehensive audio system diagnostics..."

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

echo "========================================="
echo "🎵 AUDIO SYSTEM DIAGNOSTIC REPORT"
echo "========================================="
echo "Generated: $(date)"
echo ""

# 1. Check PipeWire Status
blue "1. PipeWire Service Status"
echo "----------------------------------------"
if pgrep -f pipewire >/dev/null; then
    green "✅ PipeWire daemon is running"
    echo "   PID: $(pgrep -f pipewire)"
else
    red "❌ PipeWire daemon is not running"
fi

if command -v pw-cli >/dev/null 2>&1; then
    if pw-cli info >/dev/null 2>&1; then
        green "✅ PipeWire client connection working"
    else
        red "❌ Cannot connect to PipeWire daemon"
    fi
else
    red "❌ pw-cli command not found"
fi
echo ""

# 2. Check WirePlumber Status
blue "2. WirePlumber Session Manager"
echo "----------------------------------------"
if pgrep -f wireplumber >/dev/null; then
    green "✅ WirePlumber is running"
    echo "   PID: $(pgrep -f wireplumber)"
else
    yellow "⚠️  WirePlumber is not running"
fi

if command -v wpctl >/dev/null 2>&1; then
    if wpctl status >/dev/null 2>&1; then
        green "✅ WirePlumber client connection working"
    else
        yellow "⚠️  Cannot connect to WirePlumber"
    fi
else
    yellow "⚠️  wpctl command not found"
fi
echo ""

# 3. Check Audio Devices
blue "3. Audio Devices"
echo "----------------------------------------"
if command -v wpctl >/dev/null 2>&1 && wpctl status >/dev/null 2>&1; then
    echo "Available Audio Sinks:"
    wpctl status | grep -A 10 "Audio" | grep -A 5 "Sinks:" || echo "  No sinks found"
    echo ""
    echo "Available Audio Sources:"
    wpctl status | grep -A 10 "Audio" | grep -A 5 "Sources:" || echo "  No sources found"
    echo ""
    
    # Check for virtual devices specifically
    if wpctl status | grep -q "virtual_speaker"; then
        green "✅ virtual_speaker device found"
    else
        red "❌ virtual_speaker device missing"
    fi
    
    if wpctl status | grep -q "virtual_microphone"; then
        green "✅ virtual_microphone device found"
    else
        yellow "⚠️  virtual_microphone device missing"
    fi
else
    red "❌ Cannot query audio devices"
fi
echo ""

# 4. Check WebRTC Bridge
blue "4. WebRTC Audio Bridge"
echo "----------------------------------------"
if pgrep -f "node.*server.js" >/dev/null; then
    green "✅ WebRTC bridge process is running"
    echo "   PID: $(pgrep -f "node.*server.js")"
else
    red "❌ WebRTC bridge process not found"
fi

# Test HTTP endpoint
if curl -s --connect-timeout 5 http://localhost:8080/package.json >/dev/null 2>&1; then
    green "✅ WebRTC bridge HTTP server responding (port 8080)"
else
    red "❌ WebRTC bridge HTTP server not responding (port 8080)"
fi

# Test WebSocket endpoint
if nc -z localhost 8081 2>/dev/null; then
    green "✅ WebRTC signaling WebSocket port is open (port 8081)"
else
    red "❌ WebRTC signaling WebSocket port is not accessible (port 8081)"
    echo "   This is likely the main issue - port 8081 needs to be exposed in Docker"
fi
echo ""

# 5. Check Network Ports
blue "5. Network Port Status"
echo "----------------------------------------"
echo "Listening ports related to audio:"
netstat -tlnp 2>/dev/null | grep -E ":(8080|8081) " || echo "  No audio-related ports found"
echo ""

# 6. Check noVNC Integration
blue "6. noVNC Integration"
echo "----------------------------------------"
if [ -f "/usr/share/novnc/universal-webrtc.js" ]; then
    green "✅ Universal WebRTC script is present"
else
    red "❌ Universal WebRTC script missing"
fi

if [ -f "/usr/share/novnc/index.html" ]; then
    green "✅ Custom noVNC homepage exists"
else
    yellow "⚠️  Custom noVNC homepage not found"
fi

if [ -f "/usr/share/novnc/vnc-audio.html" ]; then
    green "✅ Audio control page exists"
else
    yellow "⚠️  Audio control page not found"
fi
echo ""

# 7. Environment Check
blue "7. Environment Variables"
echo "----------------------------------------"
echo "AUDIO_HOST: ${AUDIO_HOST:-not set}"
echo "AUDIO_PORT: ${AUDIO_PORT:-not set}"
echo "AUDIO_WS_SCHEME: ${AUDIO_WS_SCHEME:-not set}"
echo ""

# 8. Recommendations
blue "8. Recommendations"
echo "----------------------------------------"

# Check if port 8081 is exposed
if ! nc -z localhost 8081 2>/dev/null; then
    red "🔧 CRITICAL: Port 8081 must be exposed in Docker Compose files"
    echo "   Add '- \"8081:8081\"' to the ports section in:"
    echo "   - docker-compose.yml"
    echo "   - docker-compose.dev.yml" 
    echo "   - docker-compose.prod.yml"
    echo ""
fi

# Check if virtual devices exist
if ! wpctl status 2>/dev/null | grep -q "virtual_speaker"; then
    yellow "🔧 Run virtual device creation:"
    echo "   /usr/local/bin/create-virtual-pipewire-devices.sh"
    echo ""
fi

# Check if WebRTC bridge is running
if ! pgrep -f "node.*server.js" >/dev/null; then
    yellow "🔧 Start WebRTC bridge:"
    echo "   cd /opt/webrtc-bridge && node server.js"
    echo ""
fi

echo "========================================="
echo "🎯 SUMMARY"
echo "========================================="

# Count issues
issues=0
if ! pgrep -f pipewire >/dev/null; then ((issues++)); fi
if ! nc -z localhost 8081 2>/dev/null; then ((issues++)); fi
if ! pgrep -f "node.*server.js" >/dev/null; then ((issues++)); fi
if ! wpctl status 2>/dev/null | grep -q "virtual_speaker"; then ((issues++)); fi

if [ $issues -eq 0 ]; then
    green "🎉 All audio systems appear to be working correctly!"
    echo "   You should be able to use WebRTC audio controls."
elif [ $issues -eq 1 ]; then
    yellow "⚠️  1 issue found - see recommendations above"
else
    red "❌ $issues issues found - see recommendations above"
fi

echo ""
echo "📋 For more detailed testing, run:"
echo "   /usr/local/bin/test-webrtc-pipeline.sh"
echo "   /usr/local/bin/audio-validation.sh"
echo ""
echo "🌐 Access your audio control page at:"
echo "   http://37.27.49.246:32768/vnc-audio.html"
echo "========================================="