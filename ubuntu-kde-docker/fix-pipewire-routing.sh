#!/bin/bash
set -euo pipefail

# PipeWire Audio Routing Fix Script
# Ensures proper audio routing to virtual devices

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

echo "🔧 Fixing PipeWire audio routing..."

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

# Function to execute PipeWire commands as user
run_as_user() {
    su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; $1"
}

# Check PipeWire status
check_pipewire_status() {
    echo "🔍 Checking PipeWire status..."
    
    if run_as_user "pw-cli info" >/dev/null 2>&1; then
        green "✅ PipeWire server is running"
    else
        red "❌ PipeWire server not accessible"
        return 1
    fi
    
    if run_as_user "wpctl status" >/dev/null 2>&1; then
        green "✅ WirePlumber session manager is running"
    else
        yellow "⚠️  WirePlumber not accessible"
    fi
}

# Fix virtual device routing
fix_virtual_device_routing() {
    echo "🎧 Fixing virtual device routing..."
    
    # Get virtual speaker ID
    local speaker_id
    speaker_id=$(run_as_user "wpctl status | grep 'virtual_speaker'" | head -1 | awk '{print $2}' | sed 's/[^0-9]//g' || echo "")
    
    if [ -n "$speaker_id" ]; then
        green "✅ Found virtual_speaker with ID: $speaker_id"
        
        # Set as default sink
        if run_as_user "wpctl set-default $speaker_id"; then
            green "✅ Set virtual_speaker as default sink"
        else
            yellow "⚠️  Failed to set virtual_speaker as default"
        fi
        
        # Set volume to 50%
        run_as_user "wpctl set-volume $speaker_id 0.5" || true
        
        # Move all existing sink inputs to virtual speaker
        local sink_inputs
        sink_inputs=$(run_as_user "wpctl status | grep -A 20 'Sink inputs:' | grep '│' | awk '{print \$2}' | sed 's/[^0-9]//g'" || echo "")
        
        if [ -n "$sink_inputs" ]; then
            echo "$sink_inputs" | while read -r input_id; do
                if [ -n "$input_id" ]; then
                    run_as_user "wpctl set-sink $input_id $speaker_id" || true
                fi
            done
            green "✅ Moved audio streams to virtual_speaker"
        fi
    else
        red "❌ virtual_speaker not found"
        return 1
    fi
    
    # Get virtual microphone monitor source ID
    local mic_source_id
    mic_source_id=$(run_as_user "wpctl status | grep 'virtual_microphone.*monitor'" | head -1 | awk '{print $2}' | sed 's/[^0-9]//g' || echo "")
    
    if [ -n "$mic_source_id" ]; then
        green "✅ Found virtual_microphone monitor with ID: $mic_source_id"
        
        # Set as default source
        if run_as_user "wpctl set-default $mic_source_id"; then
            green "✅ Set virtual_microphone monitor as default source"
        else
            yellow "⚠️  Failed to set virtual_microphone monitor as default"
        fi
        
        # Set volume to 50%
        run_as_user "wpctl set-volume $mic_source_id 0.5" || true
    else
        yellow "⚠️  virtual_microphone monitor not found"
    fi
}

# Test audio routing
test_audio_routing() {
    echo "🧪 Testing audio routing..."
    
    # Test audio generation to virtual speaker
    if command -v gst-launch-1.0 >/dev/null 2>&1; then
        echo "🔊 Testing audio generation..."
        
        # Generate test tone for 2 seconds
        if timeout 2 run_as_user "gst-launch-1.0 audiotestsrc freq=440 ! audioconvert ! pipewiresink node-name=virtual_speaker" >/dev/null 2>&1; then
            green "✅ Audio generation test passed"
        else
            yellow "⚠️  Audio generation test failed"
        fi
        
        # Test audio capture from virtual speaker monitor
        echo "🎤 Testing audio capture..."
        if timeout 2 run_as_user "gst-launch-1.0 pipewiresrc target-object=virtual_speaker.monitor ! audioconvert ! fakesink" >/dev/null 2>&1; then
            green "✅ Audio capture test passed"
        else
            yellow "⚠️  Audio capture test failed"
        fi
    else
        yellow "⚠️  GStreamer not available for testing"
    fi
}

# Display current routing status
show_routing_status() {
    echo "📊 Current PipeWire routing status:"
    echo "=================================="
    
    echo "Default Sink:"
    run_as_user "wpctl get-volume @DEFAULT_AUDIO_SINK@" || echo "Not available"
    
    echo ""
    echo "Default Source:"
    run_as_user "wpctl get-volume @DEFAULT_AUDIO_SOURCE@" || echo "Not available"
    
    echo ""
    echo "Available Sinks:"
    run_as_user "wpctl status | grep -A 10 'Audio' | grep 'Sinks:' -A 5" || echo "Not available"
    
    echo ""
    echo "Available Sources:"
    run_as_user "wpctl status | grep -A 10 'Audio' | grep 'Sources:' -A 5" || echo "Not available"
}

# Main execution
main() {
    echo "🚀 Starting PipeWire audio routing fix..."
    
    # Check if user exists
    if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
        red "❌ User $DEV_USERNAME does not exist"
        exit 1
    fi
    
    # Check PipeWire status
    if ! check_pipewire_status; then
        red "❌ PipeWire not accessible, cannot fix routing"
        exit 1
    fi
    
    # Fix routing
    fix_virtual_device_routing || yellow "⚠️  Some routing fixes failed"
    
    # Test routing
    test_audio_routing || yellow "⚠️  Some audio tests failed"
    
    # Show status
    show_routing_status
    
    green "✅ PipeWire audio routing fix completed!"
}

# Allow script to be sourced or executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi