#!/bin/bash

# Debug Audio Pipeline Script
# Comprehensive debugging tool for the audio streaming system

set -e

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }
cyan() { echo -e "\033[36m$*\033[0m"; }

echo "🔍 Audio Pipeline Debug Tool"
echo "============================"

# Step 1: Check PulseAudio Service
debug_pulseaudio_service() {
    blue "\n📡 Step 1: PulseAudio Service Status"
    echo "-----------------------------------"
    
    # Check if PulseAudio is running
    if pgrep -f pulseaudio >/dev/null; then
        green "✅ PulseAudio process is running"
        
        # Show PulseAudio processes
        echo "PulseAudio processes:"
        pgrep -f pulseaudio | while read pid; do
            ps -p $pid -o pid,user,cmd --no-headers
        done
    else
        red "❌ PulseAudio process not found"
        return 1
    fi
    
    # Test PulseAudio connectivity
    export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
    
    if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl info >/dev/null 2>&1"; then
        green "✅ PulseAudio local socket connection working"
    else
        red "❌ PulseAudio local socket connection failed"
    fi
    
    if su - "${DEV_USERNAME}" -c "pactl -s tcp:localhost:4713 info >/dev/null 2>&1"; then
        green "✅ PulseAudio TCP connection working"
    else
        red "❌ PulseAudio TCP connection failed"
    fi
}

# Step 2: Check Virtual Audio Devices
debug_virtual_devices() {
    blue "\n🔊 Step 2: Virtual Audio Devices"
    echo "--------------------------------"
    
    export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
    
    echo "Available sinks:"
    if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sinks" 2>/dev/null; then
        if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sinks" 2>/dev/null | grep -q virtual_speaker; then
            green "✅ virtual_speaker sink found"
        else
            red "❌ virtual_speaker sink missing"
        fi
    else
        red "❌ Cannot list sinks"
    fi
    
    echo -e "\nAvailable sources:"
    if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sources" 2>/dev/null; then
        if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sources" 2>/dev/null | grep -q virtual_speaker.monitor; then
            green "✅ virtual_speaker.monitor source found"
        else
            red "❌ virtual_speaker.monitor source missing"
        fi
    else
        red "❌ Cannot list sources"
    fi
    
    echo -e "\nDefault devices:"
    echo "Default sink: $(su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl get-default-sink" 2>/dev/null || echo 'NONE')"
    echo "Default source: $(su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl get-default-source" 2>/dev/null || echo 'NONE')"
}

# Step 3: Test Audio Signal Chain
debug_audio_signal() {
    blue "\n🎵 Step 3: Audio Signal Chain"
    echo "-----------------------------"
    
    export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
    
    # Test 1: Generate test audio to virtual_speaker
    echo "Test 1: Generating test tone to virtual_speaker..."
    if timeout 3 su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        pactl set-default-sink virtual_speaker 2>/dev/null
        speaker-test -t sine -f 440 -l 1 -s 1 -D pulse:virtual_speaker >/dev/null 2>&1
    "; then
        green "✅ Test tone generation successful"
    else
        yellow "⚠️  Test tone generation failed or unavailable"
    fi
    
    # Test 2: Check if virtual_speaker.monitor is receiving data
    echo -e "\nTest 2: Recording from virtual_speaker.monitor..."
    local test_file="/tmp/audio_test_$(date +%s).raw"
    
    if timeout 3 su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        parecord --device=virtual_speaker.monitor --format=s16le --rate=44100 --channels=2 --raw --duration=2 > $test_file 2>/dev/null
    " && [ -f "$test_file" ]; then
        local file_size=$(stat -c%s "$test_file" 2>/dev/null || echo 0)
        if [ "$file_size" -gt 1000 ]; then
            green "✅ Audio capture successful (${file_size} bytes)"
        else
            yellow "⚠️  Audio capture produced minimal data (${file_size} bytes)"
        fi
        rm -f "$test_file"
    else
        red "❌ Audio capture failed"
    fi
    
    # Test 3: Check current audio routing
    echo -e "\nTest 3: Current audio routing..."
    local sink_inputs
    sink_inputs=$(su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sink-inputs" 2>/dev/null || echo "")
    
    if [ -n "$sink_inputs" ]; then
        green "✅ Active audio streams found:"
        echo "$sink_inputs"
    else
        yellow "⚠️  No active audio streams"
    fi
}

# Step 4: Check Audio Bridge Service
debug_audio_bridge() {
    blue "\n🌐 Step 4: Audio Bridge Service"
    echo "-------------------------------"
    
    # Check if Node.js audio bridge is running
    if pgrep -f "node.*server.js" >/dev/null || pgrep -f "audio-bridge" >/dev/null; then
        green "✅ Audio bridge process found"
        
        echo "Audio bridge processes:"
        pgrep -f "node.*server.js\|audio-bridge" | while read pid; do
            ps -p $pid -o pid,user,cmd --no-headers 2>/dev/null || true
        done
    else
        red "❌ Audio bridge process not running"
    fi
    
    # Check if port 8080 is listening
    if netstat -tuln 2>/dev/null | grep -q ":8080 "; then
        green "✅ Port 8080 is listening"
    else
        red "❌ Port 8080 is not listening"
    fi
    
    # Test HTTP endpoint
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/audio-player.html" | grep -q "200"; then
        green "✅ Audio bridge HTTP endpoint accessible"
    else
        red "❌ Audio bridge HTTP endpoint not accessible"
    fi
}

# Step 5: Test Complete Pipeline
debug_complete_pipeline() {
    blue "\n🔄 Step 5: Complete Pipeline Test"
    echo "---------------------------------"
    
    # Start a background audio bridge test
    echo "Starting complete pipeline test..."
    
    export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
    
    # Set virtual_speaker as default
    su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        pactl set-default-sink virtual_speaker 2>/dev/null || true
    "
    
    # Generate test audio and simultaneously try to capture it
    local capture_file="/tmp/pipeline_test_$(date +%s).raw"
    
    echo "Generating test audio while monitoring pipeline..."
    
    # Start capture in background
    timeout 5 su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        parecord --device=virtual_speaker.monitor --format=s16le --rate=44100 --channels=2 --raw > $capture_file 2>/dev/null
    " &
    local capture_pid=$!
    
    sleep 1
    
    # Generate test tone
    timeout 3 su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        speaker-test -t sine -f 440 -l 1 -s 1 -D pulse:virtual_speaker >/dev/null 2>&1
    " &
    local speaker_pid=$!
    
    # Wait for both to complete
    wait $capture_pid 2>/dev/null || true
    wait $speaker_pid 2>/dev/null || true
    
    # Check results
    if [ -f "$capture_file" ]; then
        local file_size=$(stat -c%s "$capture_file" 2>/dev/null || echo 0)
        if [ "$file_size" -gt 10000 ]; then
            green "✅ Complete pipeline test successful (${file_size} bytes captured)"
        else
            yellow "⚠️  Pipeline test captured minimal data (${file_size} bytes)"
        fi
        rm -f "$capture_file"
    else
        red "❌ Complete pipeline test failed"
    fi
}

# Main execution
main() {
    echo "Starting comprehensive audio pipeline debugging..."
    echo "This will test the entire audio chain from virtual devices to WebSocket streaming."
    echo ""
    
    debug_pulseaudio_service || echo ""
    debug_virtual_devices || echo ""
    debug_audio_signal || echo ""
    debug_audio_bridge || echo ""
    debug_complete_pipeline || echo ""
    
    echo ""
    cyan "🎯 Debugging Summary"
    echo "==================="
    echo "Review the results above to identify where the audio pipeline breaks."
    echo ""
    echo "Common fixes:"
    echo "- If PulseAudio is not running: supervisorctl restart pulseaudio"
    echo "- If virtual devices are missing: /usr/local/bin/create-virtual-audio-devices.sh"
    echo "- If audio bridge is not running: supervisorctl restart audio-bridge"
    echo "- If signal chain is broken: /usr/local/bin/audio-recovery.sh"
    echo ""
    echo "For real-time monitoring, run: /usr/local/bin/audio-monitor.sh monitor"
}

main "$@"