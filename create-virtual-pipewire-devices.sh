#!/bin/bash
set -euo pipefail

# Create Virtual PipeWire Audio Devices Script
# Sets up persistent virtual audio devices (speaker and microphone) for a containerized environment

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

# Export environment variables for PipeWire
export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
export HOME="/home/${DEV_USERNAME}"

echo "🔊 Creating virtual PipeWire audio devices..."

# Function to execute PipeWire commands with fallback
run_pw_cli() {
    local cmd="$1"
    
    # Try as the user first
    if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pw-cli $cmd" 2>/dev/null; then
        return 0
    fi
    
    # Fallback: try direct execution
    if pw-cli "$cmd" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Function to execute WirePlumber commands
run_wpctl() {
    local cmd="$1"
    
    # Try as the user first
    if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; wpctl $cmd" 2>/dev/null; then
        return 0
    fi
    
    # Fallback: try direct execution
    if wpctl "$cmd" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Wait for PipeWire to be ready
wait_for_pipewire() {
    local timeout=30
    local count=0
    
    echo "🔄 Waiting for PipeWire to be ready..."
    
    while [ $count -lt $timeout ]; do
        if run_pw_cli "info" >/dev/null 2>&1; then
            echo "✅ PipeWire is ready"
            return 0
        fi
        
        if [ $count -eq 15 ]; then
            echo "⚠️  PipeWire not ready after 15 seconds, attempting restart..."
            # Try to restart PipeWire
            pkill -f pipewire || true
            sleep 2
            su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pipewire &" || true
            sleep 3
        fi
        
        sleep 1
        count=$((count + 1))
    done
    
    echo "❌ Timeout waiting for PipeWire"
    return 1
}

# Create virtual audio devices
create_virtual_devices() {
    echo "🎧 Creating virtual audio devices..."
    
    # Create virtual speaker (null sink)
    if ! run_pw_cli "create-node adapter" \
        "factory.name=support.null-audio-sink" \
        "node.name=virtual_speaker" \
        "node.description=\"Virtual Marketing Speaker\"" \
        "media.class=Audio/Sink" \
        "audio.channels=2" \
        "audio.position=FL,FR" \
        "monitor.channel-volumes=true"; then
        echo "⚠️  Failed to create virtual_speaker, trying alternative method..."
        
        # Alternative method using GStreamer
        timeout 5 gst-launch-1.0 audiotestsrc freq=0 volume=0 ! \
            audioconvert ! pipewiresink node-name=virtual_speaker &
        sleep 2
        pkill gst-launch-1.0 || true
    fi
    
    # Create virtual microphone (null sink)
    if ! run_pw_cli "create-node adapter" \
        "factory.name=support.null-audio-sink" \
        "node.name=virtual_microphone" \
        "node.description=\"Virtual Marketing Microphone\"" \
        "media.class=Audio/Sink" \
        "audio.channels=2" \
        "audio.position=FL,FR"; then
        echo "⚠️  Failed to create virtual_microphone, trying alternative method..."
        
        # Alternative method using GStreamer
        timeout 5 gst-launch-1.0 audiotestsrc freq=0 volume=0 ! \
            audioconvert ! pipewiresink node-name=virtual_microphone &
        sleep 2
        pkill gst-launch-1.0 || true
    fi
    
    # Wait for devices to be created
    sleep 3
    
    # Set virtual speaker as default sink
    if run_wpctl "status" | grep -q "virtual_speaker"; then
        local speaker_id=$(run_wpctl "status" | grep "virtual_speaker" | head -1 | awk '{print $2}' | sed 's/[^0-9]//g')
        if [ -n "$speaker_id" ]; then
            run_wpctl "set-default $speaker_id" || echo "⚠️  Failed to set default sink"
        fi
    fi
    
    # Set virtual microphone monitor as default source
    if run_wpctl "status" | grep -q "virtual_microphone"; then
        local mic_id=$(run_wpctl "status" | grep "virtual_microphone" | head -1 | awk '{print $2}' | sed 's/[^0-9]//g')
        if [ -n "$mic_id" ]; then
            # Get monitor source ID (usually mic_id + 1)
            local monitor_id=$((mic_id + 1))
            run_wpctl "set-default $monitor_id" || echo "⚠️  Failed to set default source"
        fi
    fi
    
    # Set volume levels (50% = 0.5 in PipeWire)
    run_wpctl "set-volume @DEFAULT_AUDIO_SINK@ 0.5" || true
    run_wpctl "set-volume @DEFAULT_AUDIO_SOURCE@ 0.5" || true
    
    echo "✅ Virtual audio devices created and configured"
}

# Verify devices were created successfully
verify_devices() {
    echo "🔍 Verifying virtual audio devices..."
    
    if run_pw_cli "list-objects" | grep -q "virtual_speaker"; then
        echo "✅ virtual_speaker created successfully"
    else
        echo "❌ virtual_speaker not found"
        return 1
    fi
    
    if run_pw_cli "list-objects" | grep -q "virtual_microphone"; then
        echo "✅ virtual_microphone created successfully"
    else
        echo "❌ virtual_microphone not found"
        return 1
    fi
    
    echo "🎉 All virtual devices verified successfully!"
    return 0
}

# Main execution
main() {
    echo "🚀 Starting virtual PipeWire device creation..."
    
    # Check if user exists
    if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
        echo "❌ User $DEV_USERNAME does not exist"
        exit 1
    fi
    
    # Ensure runtime directory exists
    mkdir -p "/run/user/${DEV_UID}/pipewire"
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}"
    
    # Execute the setup
    wait_for_pipewire || exit 1
    create_virtual_devices || exit 1
    verify_devices || exit 1
    
    echo "✅ Virtual PipeWire audio device creation completed successfully!"
}

main "$@"