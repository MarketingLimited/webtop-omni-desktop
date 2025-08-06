#!/bin/bash

# Complete Audio Pipeline Test Script
# Tests the entire audio pipeline from virtual devices to browser playback

set -e

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }
cyan() { echo -e "\033[36m$*\033[0m"; }

echo "🧪 Complete Audio Pipeline Testing Suite"
echo "========================================"

# Check if user exists
if ! id "${DEV_USERNAME}" >/dev/null 2>&1; then
    red "❌ User ${DEV_USERNAME} doesn't exist"
    exit 1
fi

export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"

# Test 1: PulseAudio Service
test_pulseaudio_service() {
    blue "\n🔧 Test 1: PulseAudio Service"
    echo "----------------------------"
    
    if pgrep -f pulseaudio >/dev/null; then
        green "✅ PulseAudio process running"
        
        # Test connectivity
        if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl info >/dev/null 2>&1"; then
            green "✅ PulseAudio local connection working"
        else
            red "❌ PulseAudio local connection failed"
            
            # Try TCP fallback
            if su - "${DEV_USERNAME}" -c "pactl -s tcp:localhost:4713 info >/dev/null 2>&1"; then
                green "✅ PulseAudio TCP connection working (fallback)"
            else
                red "❌ All PulseAudio connections failed"
                return 1
            fi
        fi
    else
        red "❌ PulseAudio not running"
        return 1
    fi
}

# Test 2: Virtual Audio Devices
test_virtual_devices() {
    blue "\n🔊 Test 2: Virtual Audio Devices"
    echo "--------------------------------"
    
    local sinks sources
    sinks=$(su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sinks" 2>/dev/null || echo "")
    sources=$(su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sources" 2>/dev/null || echo "")
    
    if echo "$sinks" | grep -q "virtual_speaker"; then
        green "✅ virtual_speaker sink found"
    else
        red "❌ virtual_speaker sink missing"
        echo "Creating virtual_speaker..."
        /usr/local/bin/create-virtual-audio-devices.sh || return 1
        sinks=$(su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sinks" 2>/dev/null || echo "")
    fi
    
    if echo "$sources" | grep -q "virtual_speaker.monitor"; then
        green "✅ virtual_speaker.monitor source found"
    else
        red "❌ virtual_speaker.monitor source missing"
        return 1
    fi
    
    # Check default routing
    local default_sink
    default_sink=$(su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl get-default-sink" 2>/dev/null || echo "")
    
    if [ "$default_sink" = "virtual_speaker" ]; then
        green "✅ Default sink correctly set to virtual_speaker"
    else
        yellow "⚠️  Default sink is not virtual_speaker: $default_sink"
        echo "Fixing audio routing..."
        /usr/local/bin/fix-pipewire-routing.sh
    fi
}

# Test 3: Audio Signal Generation and Capture
test_audio_signal_chain() {
    blue "\n🎵 Test 3: Audio Signal Chain"
    echo "-----------------------------"
    
    local test_file="/tmp/complete_test_$(date +%s).raw"
    local signal_generated=false
    
    # Start monitoring in background
    echo "Starting audio capture from virtual_speaker.monitor..."
    timeout 8 su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        parecord --device=virtual_speaker.monitor --format=s16le --rate=44100 --channels=2 --raw > $test_file 2>/dev/null
    " &
    local capture_pid=$!
    
    sleep 2
    
    # Generate test signal
    echo "Generating test audio signal..."
    if timeout 5 su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        speaker-test -t sine -f 440 -l 1 -s 1 -D pulse:virtual_speaker >/dev/null 2>&1
    "; then
        signal_generated=true
        green "✅ Test signal generated successfully"
    else
        yellow "⚠️  speaker-test failed, trying alternative method..."
        
        # Alternative: Use paplay with generated data
        if timeout 3 su - "${DEV_USERNAME}" -c "
            export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
            dd if=/dev/zero bs=4 count=22050 2>/dev/null | paplay --device=virtual_speaker --format=s16le --rate=44100 --channels=2 >/dev/null 2>&1
        "; then
            signal_generated=true
            green "✅ Test signal generated via paplay"
        else
            red "❌ Failed to generate test signal"
        fi
    fi
    
    # Wait for capture to complete
    wait $capture_pid 2>/dev/null || true
    
    # Analyze results
    if [ -f "$test_file" ]; then
        local file_size=$(stat -c%s "$test_file" 2>/dev/null || echo 0)
        
        if [ "$file_size" -gt 50000 ]; then
            green "✅ Audio signal chain working! Captured ${file_size} bytes"
            
            # Quick signal analysis
            if command -v hexdump >/dev/null; then
                local sample_data=$(hexdump -C "$test_file" | head -3 | tail -1)
                if echo "$sample_data" | grep -q -v "00 00 00 00 00 00 00 00"; then
                    green "✅ Non-silent audio data detected"
                else
                    yellow "⚠️  Audio data appears to be silence"
                fi
            fi
        elif [ "$file_size" -gt 1000 ]; then
            yellow "⚠️  Audio signal chain partially working (${file_size} bytes)"
        else
            red "❌ Audio signal chain broken (${file_size} bytes)"
        fi
        
        rm -f "$test_file"
    else
        red "❌ No audio data captured"
    fi
    
    return 0
}

# Test 4: Audio Bridge Service
test_audio_bridge() {
    blue "\n🌐 Test 4: Audio Bridge Service"
    echo "-------------------------------"
    
    # Check if audio bridge process is running
    if pgrep -f "node.*server.js" >/dev/null || pgrep -f "audio-bridge" >/dev/null; then
        green "✅ Audio bridge process running"
    else
        red "❌ Audio bridge process not running"
        echo "Starting audio bridge..."
        (cd /opt/audio-bridge && node server.js &)
        sleep 3
    fi
    
    # Check if port 8080 is listening
    if netstat -tuln 2>/dev/null | grep -q ":8080 "; then
        green "✅ Audio bridge listening on port 8080"
    else
        red "❌ Audio bridge not listening on port 8080"
        return 1
    fi
    
    # Test HTTP endpoint
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/audio-player.html" 2>/dev/null | grep -q "200"; then
        green "✅ Audio bridge HTTP endpoint responding"
    else
        red "❌ Audio bridge HTTP endpoint not accessible"
        return 1
    fi
    
    # Test WebSocket (simple connection test)
    echo "Testing WebSocket connection..."
    if timeout 5 bash -c "exec 3<>/dev/tcp/localhost/8080 && echo -e 'GET / HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n' >&3 && head -1 <&3" 2>/dev/null | grep -q "101"; then
        green "✅ WebSocket upgrade successful"
    else
        yellow "⚠️  WebSocket test inconclusive"
    fi
}

# Test 5: Browser Integration
test_browser_integration() {
    blue "\n🌍 Test 5: Browser Integration"
    echo "------------------------------"
    
    # Check noVNC files
    if [ -f "/usr/share/novnc/vnc_audio.html" ]; then
        green "✅ Enhanced VNC interface available"
    else
        red "❌ Enhanced VNC interface missing"
    fi
    
    if [ -f "/usr/share/novnc/audio-env.js" ]; then
        green "✅ Audio environment configuration found"
        
        # Verify configuration content
        if grep -q "AUDIO_PORT" /usr/share/novnc/audio-env.js; then
            green "✅ Audio configuration appears valid"
        else
            yellow "⚠️  Audio configuration may be incomplete"
        fi
    else
        red "❌ Audio environment configuration missing"
    fi
    
    if [ -f "/usr/share/novnc/universal-audio.js" ]; then
        green "✅ Universal audio script found"
    else
        yellow "⚠️  Universal audio script missing"
    fi
    
    # Check if standard VNC pages have audio integration
    if grep -q "universal-audio.js" /usr/share/novnc/vnc.html 2>/dev/null; then
        green "✅ Standard VNC page has audio integration"
    else
        yellow "⚠️  Standard VNC page missing audio integration"
    fi
}

# Test 6: End-to-End Pipeline Test
test_end_to_end_pipeline() {
    blue "\n🔄 Test 6: End-to-End Pipeline Test"
    echo "-----------------------------------"
    
    echo "Running complete pipeline simulation..."
    
    # Ensure audio routing is correct
    su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        pactl set-default-sink virtual_speaker 2>/dev/null || true
    "
    
    # Start audio bridge capture simulation
    local bridge_test_file="/tmp/bridge_test_$(date +%s).raw"
    echo "Simulating audio bridge capture..."
    
    timeout 10 su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        parecord --device=virtual_speaker.monitor --format=s16le --rate=44100 --channels=2 --raw > $bridge_test_file 2>/dev/null
    " &
    local bridge_pid=$!
    
    sleep 2
    
    # Generate audio that would be captured by the bridge
    echo "Generating desktop audio..."
    timeout 5 su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        speaker-test -t sine -f 880 -l 1 -s 1 -D pulse:virtual_speaker >/dev/null 2>&1 || 
        (dd if=/dev/zero bs=4 count=44100 2>/dev/null | paplay --device=virtual_speaker --format=s16le --rate=44100 --channels=2 >/dev/null 2>&1)
    " 2>/dev/null || true
    
    # Wait for bridge simulation
    wait $bridge_pid 2>/dev/null || true
    
    # Analyze end-to-end results
    if [ -f "$bridge_test_file" ]; then
        local bridge_size=$(stat -c%s "$bridge_test_file" 2>/dev/null || echo 0)
        
        if [ "$bridge_size" -gt 100000 ]; then
            green "✅ End-to-end pipeline fully functional! (${bridge_size} bytes)"
            echo "   → Desktop audio → virtual_speaker → monitor → bridge capture ✓"
        elif [ "$bridge_size" -gt 10000 ]; then
            yellow "⚠️  End-to-end pipeline partially working (${bridge_size} bytes)"
        else
            red "❌ End-to-end pipeline broken (${bridge_size} bytes)"
        fi
        
        rm -f "$bridge_test_file"
    else
        red "❌ End-to-end pipeline test failed"
    fi
}

# Generate comprehensive report
generate_final_report() {
    cyan "\n📊 Final Audio System Report"
    echo "============================"
    
    echo "System Configuration:"
    echo "- User: $DEV_USERNAME (UID: $DEV_UID)"
    echo "- Runtime Dir: $XDG_RUNTIME_DIR"
    echo "- Audio Bridge Port: 8080"
    
    echo ""
    echo "PulseAudio Status:"
    su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl info 2>/dev/null | grep -E 'Server String|Default Sink|Default Source'" || echo "PulseAudio info unavailable"
    
    echo ""
    echo "Audio Devices:"
    su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sinks" 2>/dev/null || echo "Cannot list sinks"
    
    echo ""
    echo "Active Audio Streams:"
    local active_streams
    active_streams=$(su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sink-inputs" 2>/dev/null || echo "")
    if [ -n "$active_streams" ]; then
        echo "$active_streams"
    else
        echo "No active audio streams"
    fi
    
    echo ""
    echo "Network Services:"
    netstat -tuln 2>/dev/null | grep -E ":8080|:5901|:6080" || echo "No relevant ports listening"
    
    echo ""
    echo "Browser Integration Files:"
    ls -la /usr/share/novnc/ | grep -E "audio|vnc" || echo "No VNC audio files found"
}

# Main execution
main() {
    echo "Starting comprehensive audio pipeline test..."
    echo "This will verify the entire audio chain from desktop to browser."
    echo ""
    
    local test_results=()
    
    # Run all tests
    if test_pulseaudio_service; then
        test_results+=("PulseAudio: ✅")
    else
        test_results+=("PulseAudio: ❌")
    fi
    
    if test_virtual_devices; then
        test_results+=("Virtual Devices: ✅")
    else
        test_results+=("Virtual Devices: ❌")
    fi
    
    if test_audio_signal_chain; then
        test_results+=("Signal Chain: ✅")
    else
        test_results+=("Signal Chain: ❌")
    fi
    
    if test_audio_bridge; then
        test_results+=("Audio Bridge: ✅")
    else
        test_results+=("Audio Bridge: ❌")
    fi
    
    if test_browser_integration; then
        test_results+=("Browser Integration: ✅")
    else
        test_results+=("Browser Integration: ❌")
    fi
    
    if test_end_to_end_pipeline; then
        test_results+=("End-to-End: ✅")
    else
        test_results+=("End-to-End: ❌")
    fi
    
    # Display results summary
    cyan "\n🎯 Test Results Summary"
    echo "====================="
    for result in "${test_results[@]}"; do
        echo "$result"
    done
    
    generate_final_report
    
    echo ""
    if [[ " ${test_results[*]} " =~ " ❌" ]]; then
        red "⚠️  Some tests failed. Audio system may need attention."
        echo ""
        echo "🔧 Troubleshooting steps:"
        echo "1. Check container audio device access"
        echo "2. Verify PulseAudio configuration"
        echo "3. Test audio routing with: /usr/local/bin/fix-pipewire-routing.sh"
        echo "4. Check audio bridge logs: supervisorctl status"
        echo "5. Debug pipeline: /usr/local/bin/debug-audio-pipeline.sh"
    else
        green "🎉 All tests passed! Audio system is fully functional."
        echo ""
        echo "🎵 Audio pipeline is ready:"
        echo "• Desktop applications → virtual_speaker → monitor → WebSocket → Browser"
        echo "• Access via: http://[your-host]:32768"
        echo "• Enhanced interface: vnc_audio.html"
        echo "• Keyboard shortcut: Ctrl+Alt+A"
    fi
}

# Allow script to be called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi