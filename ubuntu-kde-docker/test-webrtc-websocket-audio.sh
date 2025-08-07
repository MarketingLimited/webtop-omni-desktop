#!/bin/bash
# Test WebRTC and WebSocket Audio Streaming
# Comprehensive test script for the audio bridge

set -e

echo "🧪 Testing WebRTC and WebSocket Audio Streaming..."

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

# Test 1: Check if Node.js dependencies are installed
test_node_dependencies() {
    echo "🔍 Testing Node.js dependencies..."
    
    cd /opt/audio-bridge
    
    if [ -f "package.json" ]; then
        green "✅ package.json found"
    else
        red "❌ package.json not found"
        return 1
    fi
    
    if [ -d "node_modules" ]; then
        green "✅ node_modules directory found"
    else
        red "❌ node_modules directory not found"
        return 1
    fi
    
    # Check specific dependencies
    if [ -d "node_modules/express" ]; then
        green "✅ Express.js installed"
    else
        red "❌ Express.js not installed"
    fi
    
    if [ -d "node_modules/ws" ]; then
        green "✅ WebSocket (ws) installed"
    else
        red "❌ WebSocket (ws) not installed"
    fi
    
    if [ -d "node_modules/wrtc" ]; then
        green "✅ WebRTC (wrtc) installed"
    else
        yellow "⚠️ WebRTC (wrtc) not installed - WebSocket fallback only"
    fi
}

# Test 2: Check if audio bridge server file exists
test_server_files() {
    echo "🔍 Testing server files..."
    
    if [ -f "/opt/audio-bridge/webrtc-audio-server.cjs" ]; then
        green "✅ WebRTC audio server found"
    else
        red "❌ WebRTC audio server not found"
        return 1
    fi
    
    if [ -f "/opt/audio-bridge/public/audio-player.html" ]; then
        green "✅ Audio player HTML found"
    else
        red "❌ Audio player HTML not found"
        return 1
    fi
}

# Test 3: Check if PulseAudio is working
test_pulseaudio() {
    echo "🔍 Testing PulseAudio..."
    
    export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
    
    if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl info" >/dev/null 2>&1; then
        green "✅ PulseAudio is responding"
    else
        red "❌ PulseAudio is not responding"
        return 1
    fi
    
    # Check for virtual audio devices
    if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sinks" | grep -q "virtual_speaker"; then
        green "✅ Virtual speaker device found"
    else
        yellow "⚠️ Virtual speaker device not found"
    fi
    
    if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sources" | grep -q "virtual_speaker.monitor"; then
        green "✅ Virtual speaker monitor found"
    else
        yellow "⚠️ Virtual speaker monitor not found"
    fi
}

# Test 4: Start audio bridge server and test endpoints
test_audio_bridge_server() {
    echo "🔍 Testing audio bridge server..."
    
    # Kill any existing server
    pkill -f "webrtc-audio-server" || true
    sleep 2
    
    # Start server in background
    cd /opt/audio-bridge
    nohup node webrtc-audio-server.cjs > /tmp/audio-bridge-test.log 2>&1 &
    SERVER_PID=$!
    
    # Wait for server to start
    sleep 5
    
    # Check if server is running
    if kill -0 $SERVER_PID 2>/dev/null; then
        green "✅ Audio bridge server started (PID: $SERVER_PID)"
    else
        red "❌ Audio bridge server failed to start"
        cat /tmp/audio-bridge-test.log
        return 1
    fi
    
    # Test health endpoint
    if curl -s http://localhost:8080/health | grep -q "ok"; then
        green "✅ Health endpoint responding"
    else
        red "❌ Health endpoint not responding"
        curl -s http://localhost:8080/health || echo "No response"
    fi
    
    # Test if port is listening
    if netstat -tlnp | grep -q ":8080"; then
        green "✅ Server listening on port 8080"
    else
        red "❌ Server not listening on port 8080"
    fi
    
    # Test WebSocket endpoint
    if command -v wscat >/dev/null 2>&1; then
        if timeout 3 wscat -c ws://localhost:8080/audio-stream --close 2>/dev/null; then
            green "✅ WebSocket endpoint accessible"
        else
            yellow "⚠️ WebSocket endpoint test failed"
        fi
    else
        yellow "⚠️ wscat not available for WebSocket testing"
    fi
    
    # Clean up
    kill $SERVER_PID 2>/dev/null || true
}

# Test 5: Test audio capture
test_audio_capture() {
    echo "🔍 Testing audio capture..."
    
    export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
    
    # Test parecord with virtual speaker monitor
    if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; timeout 2 parecord --device=virtual_speaker.monitor --format=s16le --rate=44100 --channels=2 --raw" >/dev/null 2>&1; then
        green "✅ Audio capture from virtual speaker monitor works"
    else
        yellow "⚠️ Audio capture from virtual speaker monitor failed"
        
        # Try fallback method
        if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; timeout 2 parecord --format=s16le --rate=44100 --channels=2 --raw" >/dev/null 2>&1; then
            green "✅ Audio capture from default source works"
        else
            red "❌ Audio capture failed"
        fi
    fi
}

# Test 6: Check web files accessibility
test_web_files() {
    echo "🔍 Testing web files accessibility..."
    
    # Check if files are copied to noVNC directory
    if [ -f "/usr/share/novnc/audio-player.html" ]; then
        green "✅ Audio player copied to noVNC directory"
    else
        yellow "⚠️ Audio player not found in noVNC directory"
    fi
    
    if [ -f "/usr/share/novnc/vnc_audio.html" ]; then
        green "✅ VNC with audio page found"
    else
        yellow "⚠️ VNC with audio page not found"
    fi
}

# Test 7: Test supervisor configuration
test_supervisor_config() {
    echo "🔍 Testing supervisor configuration..."
    
    if grep -q "webrtc-audio-server.cjs" /etc/supervisor/conf.d/supervisord.conf; then
        green "✅ AudioBridge service configured in supervisor"
    else
        red "❌ AudioBridge service not configured in supervisor"
    fi
    
    # Check if supervisor can start the service
    if command -v supervisorctl >/dev/null 2>&1; then
        if supervisorctl status AudioBridge 2>/dev/null | grep -q "RUNNING\|STARTING"; then
            green "✅ AudioBridge service is running"
        else
            yellow "⚠️ AudioBridge service not running"
            supervisorctl status AudioBridge 2>/dev/null || echo "Service not found"
        fi
    fi
}

# Test 8: Generate test report
generate_test_report() {
    echo ""
    blue "📋 Test Report Summary"
    echo "====================="
    
    echo "🔧 System Information:"
    echo "  - Node.js version: $(node --version 2>/dev/null || echo 'Not found')"
    echo "  - npm version: $(npm --version 2>/dev/null || echo 'Not found')"
    echo "  - PulseAudio version: $(pulseaudio --version 2>/dev/null || echo 'Not found')"
    
    echo ""
    echo "📁 File Status:"
    echo "  - Audio bridge directory: $([ -d /opt/audio-bridge ] && echo 'Exists' || echo 'Missing')"
    echo "  - WebRTC server: $([ -f /opt/audio-bridge/webrtc-audio-server.cjs ] && echo 'Exists' || echo 'Missing')"
    echo "  - Audio player: $([ -f /opt/audio-bridge/public/audio-player.html ] && echo 'Exists' || echo 'Missing')"
    echo "  - noVNC integration: $([ -f /usr/share/novnc/vnc_audio.html ] && echo 'Exists' || echo 'Missing')"
    
    echo ""
    echo "🌐 Network Status:"
    echo "  - Port 8080 listening: $(netstat -tlnp | grep -q ':8080' && echo 'Yes' || echo 'No')"
    
    echo ""
    echo "🎵 Audio Status:"
    export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
    echo "  - PulseAudio running: $(su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl info" >/dev/null 2>&1 && echo 'Yes' || echo 'No')"
    echo "  - Virtual devices: $(su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sinks" 2>/dev/null | grep -c virtual || echo '0')"
    
    echo ""
    blue "🚀 Ready to test audio streaming at:"
    echo "  - Standalone player: http://localhost:32768/audio-player.html"
    echo "  - VNC with audio: http://localhost:32768/vnc_audio.html"
    echo "  - Health check: http://localhost:32768/health"
}

# Main test execution
main() {
    echo "🧪 Starting WebRTC/WebSocket Audio Tests..."
    echo "==========================================="
    
    test_node_dependencies
    test_server_files
    test_pulseaudio
    test_audio_bridge_server
    test_audio_capture
    test_web_files
    test_supervisor_config
    generate_test_report
    
    echo ""
    green "🎉 Audio streaming tests completed!"
    echo ""
    blue "Next steps:"
    echo "1. Build and run the Docker container"
    echo "2. Open http://YOUR_SERVER_IP:32768/audio-player.html"
    echo "3. Click 'Connect Audio' and test with desktop applications"
}

# Run tests
main "$@"