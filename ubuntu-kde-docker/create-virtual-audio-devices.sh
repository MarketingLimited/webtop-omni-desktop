#!/bin/bash
# Virtual Audio Device Creation Script
# Creates persistent virtual audio devices for container environment

set -e

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"

echo "🔊 Creating persistent virtual audio devices..."

# Ensure proper environment setup
export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
export PULSE_RUNTIME_PATH="/run/user/${DEV_UID}/pulse"

# Wait for PulseAudio to be ready
wait_for_pulseaudio() {
    local timeout=30
    echo "⏳ Waiting for PulseAudio to be ready..."
    
    while [ $timeout -gt 0 ]; do
        if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl info >/dev/null 2>&1"; then
            echo "✅ PulseAudio is ready"
            return 0
        fi
        sleep 1
        timeout=$((timeout - 1))
    done
    
    echo "❌ PulseAudio not ready after 30 seconds"
    return 1
}

# Create virtual audio devices
create_virtual_devices() {
    echo "🔧 Creating virtual audio devices..."
    
    # Create virtual speaker
    if ! su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sinks | grep -q virtual_speaker"; then
        echo "Creating virtual speaker..."
        su - "${DEV_USERNAME}" -c "
            export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
            pactl load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description=\"Virtual_Marketing_Speaker\"
        "
    else
        echo "✅ Virtual speaker already exists"
    fi
    
    # Create virtual microphone
    if ! su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sinks | grep -q virtual_microphone"; then
        echo "Creating virtual microphone..."
        su - "${DEV_USERNAME}" -c "
            export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
            pactl load-module module-null-sink sink_name=virtual_microphone sink_properties=device.description=\"Virtual_Marketing_Microphone\"
        "
    else
        echo "✅ Virtual microphone already exists"
    fi
    
    # Create virtual microphone source
    if ! su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sources | grep -q virtual_mic_source"; then
        echo "Creating virtual microphone source..."
        su - "${DEV_USERNAME}" -c "
            export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
            pactl load-module module-virtual-source source_name=virtual_mic_source master=virtual_microphone.monitor source_properties=device.description=\"Virtual_Marketing_Mic_Source\"
        "
    else
        echo "✅ Virtual microphone source already exists"
    fi
    
    # Set defaults
    echo "🎯 Setting default audio devices..."
    su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        pactl set-default-sink virtual_speaker
        pactl set-default-source virtual_mic_source
        pactl set-sink-volume virtual_speaker 50%
        pactl set-sink-volume virtual_microphone 50%
    "
    
    echo "✅ Virtual audio devices created successfully"
}

# Verify devices are working
verify_devices() {
    echo "🔍 Verifying virtual audio devices..."
    
    local sink_count
    local source_count
    
    sink_count=$(su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sinks | wc -l")
    source_count=$(su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sources | wc -l")
    
    echo "Found $sink_count sinks and $source_count sources"
    
    if [ "$sink_count" -gt 0 ] && [ "$source_count" -gt 0 ]; then
        echo "✅ Audio devices verification successful"
        
        # List devices for confirmation
        echo "Available sinks:"
        su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sinks"
        
        echo "Available sources:"
        su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sources"
        
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