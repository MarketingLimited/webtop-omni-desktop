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

# Try to restart PulseAudio as root and start it as the dev user
pkill -u "${DEV_UID}" pulseaudio || true
sleep 2
rm -rf "${XDG_RUNTIME_DIR}/pulse/"* || true
mkdir -p "${XDG_RUNTIME_DIR}/pulse"
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"
su - "${DEV_USERNAME}" -c "
    export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}
    export PULSE_RUNTIME_PATH=${XDG_RUNTIME_DIR}/pulse
    pulseaudio --start --daemonize
"

    sleep 5
    if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl info >/dev/null 2>&1"; then
        echo "✅ PulseAudio restarted successfully"
        return 0
    fi

    echo "❌ PulseAudio restart failed"
    return 1
}

# Create virtual audio devices
create_virtual_devices() {
    echo "🔧 Creating virtual audio devices..."
    
    # Function to run pactl with fallback servers and explicit exit codes
    run_pactl() {
        local cmd="$1"
        local output
        local exit_code

        output=$(su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl $cmd" 2>&1)
        exit_code=$?

        if [ $exit_code -ne 0 ]; then
            output=$(su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl -s tcp:localhost:4713 $cmd" 2>&1)
            exit_code=$?
        fi

        if [ $exit_code -ne 0 ]; then
            echo "$output" >&2
        else
            echo "$output"
        fi

        return $exit_code
    }

    # Check current sinks and create virtual speaker if needed
    local current_sinks
    if ! current_sinks=$(run_pactl "list short sinks" 2>&1); then
        echo "❌ Failed to list sinks: $current_sinks" >&2
        return 1
    fi

    if ! echo "$current_sinks" | grep -q virtual_speaker; then
        echo "Creating virtual speaker..."
        local output
        if ! output=$(run_pactl "load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description=\"Virtual_Marketing_Speaker\"" 2>&1); then
            echo "❌ Failed to create virtual speaker: $output" >&2
            return 1
        fi
        echo "✅ Virtual speaker created successfully"
    else
        echo "✅ Virtual speaker already exists"
    fi

    # Create virtual microphone
    if ! current_sinks=$(run_pactl "list short sinks" 2>&1); then
        echo "❌ Failed to list sinks: $current_sinks" >&2
        return 1
    fi
    if ! echo "$current_sinks" | grep -q virtual_microphone; then
        echo "Creating virtual microphone..."
        local output
        if ! output=$(run_pactl "load-module module-null-sink sink_name=virtual_microphone sink_properties=device.description=\"Virtual_Marketing_Microphone\"" 2>&1); then
            echo "❌ Failed to create virtual microphone: $output" >&2
            return 1
        fi
        echo "✅ Virtual microphone created successfully"
    else
        echo "✅ Virtual microphone already exists"
    fi

    # Create virtual microphone source
    local current_sources
    if ! current_sources=$(run_pactl "list short sources" 2>&1); then
        echo "❌ Failed to list sources: $current_sources" >&2
        return 1
    fi
    if ! echo "$current_sources" | grep -q virtual_mic_source; then
        echo "Creating virtual microphone source..."
        local output
        if ! output=$(run_pactl "load-module module-virtual-source source_name=virtual_mic_source master=virtual_microphone.monitor source_properties=device.description=\"Virtual_Marketing_Mic_Source\"" 2>&1); then
            echo "❌ Failed to create virtual microphone source: $output" >&2
            return 1
        fi
        echo "✅ Virtual microphone source created successfully"
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
    if ! wait_for_pulseaudio; then
        echo "❌ PulseAudio setup failed. Aborting."
        exit 1
    fi
    if ! create_virtual_devices; then
        echo "❌ Virtual audio device creation failed. Aborting."
        exit 1
    fi
    verify_devices
    
    echo "🎵 Virtual audio device setup completed successfully!"
}

main "$@"
