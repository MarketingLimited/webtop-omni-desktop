#!/bin/bash
# Virtual Audio Device Creation Script
# Creates persistent virtual audio devices for container environment

set -e

DEV_USERNAME="${DEV_USERNAME:-devuser}"
# Determine UID dynamically so audio setup works when the container user has a
# non-default UID (e.g. when mapped to host user IDs).
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

echo "🔊 Creating persistent virtual audio devices..."

# Ensure proper environment setup
export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
export PULSE_RUNTIME_PATH="/run/user/${DEV_UID}/pulse"

# Run pactl with fallback to TCP server if local socket is unavailable
run_pactl() {
    local cmd="$1"
    su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl $cmd" 2>/dev/null || \
    su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl -s tcp:localhost:4713 $cmd" 2>/dev/null
}

# Wait for PulseAudio to be ready
wait_for_pulseaudio() {
    local timeout=60
    echo "⏳ Waiting for PulseAudio to be ready..."
    
    while [ $timeout -gt 0 ]; do
        # Try local socket first, then TCP fallback
        if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl info >/dev/null 2>&1"; then
            echo "✅ PulseAudio is ready (local)"
            return 0
        elif su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl -s tcp:localhost:4713 info >/dev/null 2>&1"; then
            echo "✅ PulseAudio is ready (TCP)"
            return 0
        fi
        
        if [ $((timeout % 10)) -eq 0 ]; then
            echo "Still waiting for PulseAudio... ($timeout seconds remaining)"
        fi
        
        sleep 1
        timeout=$((timeout - 1))
    done
    
    echo "❌ PulseAudio not ready after 60 seconds"
    echo "🔧 Attempting PulseAudio restart..."
    
    # Try to restart PulseAudio
    su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        export PULSE_RUNTIME_PATH=/run/user/${DEV_UID}/pulse
        pkill -f pulseaudio || true
        sleep 2
        pulseaudio --daemonize --start
    "
    
    sleep 5
    if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl info >/dev/null 2>&1"; then
        echo "✅ PulseAudio restarted successfully"
        return 0
    fi
    
    return 1
}

# Create virtual audio devices
create_virtual_devices() {
    echo "🔧 Creating virtual audio devices..."

    # Check current sinks and create virtual speaker if needed
    local current_sinks
    current_sinks=$(run_pactl "list short sinks" || echo "")
    
    if ! echo "$current_sinks" | grep -q virtual_speaker; then
        echo "Creating virtual speaker..."
        if run_pactl "load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description=\"Virtual_Marketing_Speaker\""; then
            echo "✅ Virtual speaker created successfully"
        else
            echo "⚠️ Failed to create virtual speaker, trying alternative method..."
            su - "${DEV_USERNAME}" -c "
                export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
                export PULSE_RUNTIME_PATH=/run/user/${DEV_UID}/pulse
                pactl -s tcp:localhost:4713 load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description=\"Virtual_Marketing_Speaker\" 2>/dev/null || echo 'Alternative method also failed'
            " || true
        fi
    else
        echo "✅ Virtual speaker already exists"
    fi
    
    # Create virtual microphone
    if ! run_pactl "list short sinks" | grep -q virtual_microphone; then
        echo "Creating virtual microphone..."
        if ! run_pactl "load-module module-null-sink sink_name=virtual_microphone sink_properties=device.description=\"Virtual_Marketing_Microphone\""; then
            echo "⚠️ Failed to create virtual microphone, using fallback method"
            su - "${DEV_USERNAME}" -c "
                export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
                export PULSE_RUNTIME_PATH=/run/user/${DEV_UID}/pulse
                pactl -s tcp:localhost:4713 load-module module-null-sink sink_name=virtual_microphone sink_properties=device.description=\"Virtual_Marketing_Microphone\" || true
            "
        fi
    else
        echo "✅ Virtual microphone already exists"
    fi
    
    # Create virtual microphone source
    if ! run_pactl "list short sources" | grep -q virtual_mic_source; then
        echo "Creating virtual microphone source..."
        if ! run_pactl "load-module module-virtual-source source_name=virtual_mic_source master=virtual_microphone.monitor source_properties=device.description=\"Virtual_Marketing_Mic_Source\""; then
            echo "⚠️ Failed to create virtual microphone source, using fallback method"
            su - "${DEV_USERNAME}" -c "
                export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
                export PULSE_RUNTIME_PATH=/run/user/${DEV_UID}/pulse
                pactl -s tcp:localhost:4713 load-module module-virtual-source source_name=virtual_mic_source master=virtual_microphone.monitor source_properties=device.description=\"Virtual_Marketing_Mic_Source\" || true
            "
        fi
    else
        echo "✅ Virtual microphone source already exists"
    fi
    
    # Set defaults with error handling
    echo "🎯 Setting default audio devices..."
    su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        export PULSE_RUNTIME_PATH=/run/user/${DEV_UID}/pulse
        
        # Try local socket first, then TCP fallback
        if pactl set-default-sink virtual_speaker 2>/dev/null; then
            echo 'Set default sink via local socket'
        elif pactl -s tcp:localhost:4713 set-default-sink virtual_speaker 2>/dev/null; then
            echo 'Set default sink via TCP'
        fi
        
        if pactl set-default-source virtual_mic_source 2>/dev/null; then
            echo 'Set default source via local socket'
        elif pactl -s tcp:localhost:4713 set-default-source virtual_mic_source 2>/dev/null; then
            echo 'Set default source via TCP'
        fi
        
        # Set volume levels
        pactl set-sink-volume virtual_speaker 50% 2>/dev/null || pactl -s tcp:localhost:4713 set-sink-volume virtual_speaker 50% 2>/dev/null || true
        pactl set-sink-volume virtual_microphone 50% 2>/dev/null || pactl -s tcp:localhost:4713 set-sink-volume virtual_microphone 50% 2>/dev/null || true
    "
    
    echo "✅ Virtual audio devices created successfully"
}

# Verify devices are working
verify_devices() {
    echo "🔍 Verifying virtual audio devices..."
    
    local sink_count
    local source_count
    
    local sink_output
    local source_output

    sink_output=$(run_pactl "list short sinks" || echo "")
    source_output=$(run_pactl "list short sources" || echo "")

    sink_count=$(echo "$sink_output" | wc -l)
    source_count=$(echo "$source_output" | wc -l)
    
    echo "Found $sink_count sinks and $source_count sources"
    
    if [ "$sink_count" -gt 0 ] && [ "$source_count" -gt 0 ]; then
        echo "✅ Audio devices verification successful"
        
        # List devices for confirmation
        echo "Available sinks:"
        echo "$sink_output"

        echo "Available sources:"
        echo "$source_output"
        
        return 0
    else
        echo "❌ Audio devices verification failed"
        return 1
    fi
}

# Main execution
main() {
    # Check if user exists
    if ! id "${DEV_USERNAME}" >/dev/null 2>&1; then
        echo "❌ User ${DEV_USERNAME} doesn't exist yet"
        exit 1
    fi
    
    # Ensure runtime directory exists
    mkdir -p "/run/user/${DEV_UID}/pulse"
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}"
    
    # Execute the device creation process
    wait_for_pulseaudio
    create_virtual_devices
    verify_devices
    
    echo "🎵 Virtual audio device setup completed successfully!"
}

main "$@"