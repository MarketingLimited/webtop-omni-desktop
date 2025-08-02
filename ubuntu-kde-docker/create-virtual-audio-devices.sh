#!/bin/bash
# Virtual Audio Device Creation Script
# Creates persistent virtual audio devices for container environment

set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"

echo "🔊 Creating persistent virtual audio devices..."

# Environment used when calling pactl as the dev user
PA_ENV="export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; export PULSE_RUNTIME_PATH=/run/user/${DEV_UID}/pulse"

wait_for_pulseaudio() {
    local timeout=60
    echo "⏳ Waiting for PulseAudio to be ready..."

    while [ $timeout -gt 0 ]; do
        if su - "$DEV_USERNAME" -c "$PA_ENV; pactl info" >/dev/null 2>&1; then
            echo "✅ PulseAudio is ready (local)"
            return 0
        elif su - "$DEV_USERNAME" -c "$PA_ENV; pactl -s tcp:localhost:4713 info" >/dev/null 2>&1; then
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

    su - "$DEV_USERNAME" -c "
        $PA_ENV
        pkill -f pulseaudio || true
        sleep 2
        pulseaudio --daemonize --start
    "

    sleep 5
    if su - "$DEV_USERNAME" -c "$PA_ENV; pactl info" >/dev/null 2>&1; then
        echo "✅ PulseAudio restarted successfully"
        return 0
    fi

    return 1
}

# Run pactl with a TCP fallback. Prints command output on success.
pactl_cmd() {
    local cmd="$1"
    local output
    if output=$(su - "$DEV_USERNAME" -c "$PA_ENV; pactl $cmd" 2>/dev/null); then
        printf '%s\n' "$output"
        return 0
    elif output=$(su - "$DEV_USERNAME" -c "$PA_ENV; pactl -s tcp:localhost:4713 $cmd" 2>/dev/null); then
        printf '%s\n' "$output"
        return 0
    else
        return 1
    fi
}

create_virtual_devices() {
    echo "🔧 Creating virtual audio devices..."

    if ! pactl_cmd "list short sinks" | grep -q virtual_speaker; then
        echo "Creating virtual speaker..."
        pactl_cmd "load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description=\\\"Virtual_Marketing_Speaker\\\"" >/dev/null || echo "⚠️  Failed to create virtual speaker"
    else
        echo "✅ Virtual speaker already exists"
    fi

    if ! pactl_cmd "list short sinks" | grep -q virtual_microphone; then
        echo "Creating virtual microphone..."
        pactl_cmd "load-module module-null-sink sink_name=virtual_microphone sink_properties=device.description=\\\"Virtual_Marketing_Microphone\\\"" >/dev/null || echo "⚠️  Failed to create virtual microphone"
    else
        echo "✅ Virtual microphone already exists"
    fi

    if ! pactl_cmd "list short sources" | grep -q virtual_mic_source; then
        echo "Creating virtual microphone source..."
        pactl_cmd "load-module module-virtual-source source_name=virtual_mic_source master=virtual_microphone.monitor source_properties=device.description=\\\"Virtual_Marketing_Mic_Source\\\"" >/dev/null || echo "⚠️  Failed to create virtual microphone source"
    else
        echo "✅ Virtual microphone source already exists"
    fi

    echo "🎯 Setting default audio devices..."
    su - "$DEV_USERNAME" -c "
        $PA_ENV
        pactl set-default-sink virtual_speaker 2>/dev/null || pactl -s tcp:localhost:4713 set-default-sink virtual_speaker 2>/dev/null || true
        pactl set-default-source virtual_mic_source 2>/dev/null || pactl -s tcp:localhost:4713 set-default-source virtual_mic_source 2>/dev/null || true
        pactl set-sink-volume virtual_speaker 50% 2>/dev/null || pactl -s tcp:localhost:4713 set-sink-volume virtual_speaker 50% 2>/dev/null || true
        pactl set-sink-volume virtual_microphone 50% 2>/dev/null || pactl -s tcp:localhost:4713 set-sink-volume virtual_microphone 50% 2>/dev/null || true
    "

    echo "✅ Virtual audio devices created successfully"
}

verify_devices() {
    echo "🔍 Verifying virtual audio devices..."

    local sink_count source_count

    if ! sink_count=$(pactl_cmd "list short sinks" | wc -l); then
        echo "❌ Failed to list sinks"
        return 1
    fi

    if ! source_count=$(pactl_cmd "list short sources" | wc -l); then
        echo "❌ Failed to list sources"
        return 1
    fi

    echo "Found $sink_count sinks and $source_count sources"

    if [ "$sink_count" -gt 0 ] && [ "$source_count" -gt 0 ]; then
        echo "✅ Audio devices verification successful"
        echo "Available sinks:"
        pactl_cmd "list short sinks"
        echo "Available sources:"
        pactl_cmd "list short sources"
        return 0
    else
        echo "❌ Audio devices verification failed"
        return 1
    fi
}

main() {
    if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
        echo "❌ User ${DEV_USERNAME} doesn't exist yet"
        exit 1
    fi

    mkdir -p "/run/user/${DEV_UID}/pulse"
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}"

    wait_for_pulseaudio
    create_virtual_devices
    verify_devices

    echo "🎵 Virtual audio device setup completed successfully!"
}

main "$@"

