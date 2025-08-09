#!/bin/bash
# Audio Monitor Script - Continuous monitoring of audio system
# Marketing Agency WebTop Audio System

set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
LOG_FILE="/var/log/supervisor/audio-monitor.log"

log_audio() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [AUDIO] $1" | tee -a "$LOG_FILE"
}

check_pulseaudio() {
    if pgrep -x pulseaudio >/dev/null; then
        log_audio "✅ PulseAudio daemon is running"
        return 0
    else
        log_audio "❌ PulseAudio daemon is not running"
        return 1
    fi
}

check_audio_devices() {
    local device_count
    export XDG_RUNTIME_DIR="/run/user/${DEV_UID:-1000}"
    
    # Check if user exists before attempting to switch to user context
    if ! id "${DEV_USERNAME}" >/dev/null 2>&1; then
        log_audio "⚠️  User ${DEV_USERNAME} doesn't exist yet, skipping device check"
        return 1
    fi
    
    # Gracefully handle pactl failures
    if ! device_count=$(su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID:-1000}; pactl list short sinks 2>/dev/null | wc -l" 2>/dev/null); then
        log_audio "⚠️  Could not connect to PulseAudio server"
        return 1
    fi
    
    if [ "$device_count" -gt 0 ]; then
        log_audio "✅ Audio devices available: $device_count sinks"
        ensure_default_sink
        return 0
    else
        log_audio "⚠️  No audio devices available - will attempt recovery"
        # Try to create virtual devices if missing
        attempt_device_recovery
        return 1
    fi
}

attempt_device_recovery() {
    log_audio "🔄 Attempting to create missing virtual audio devices..."
    
    if ! id "${DEV_USERNAME}" >/dev/null 2>&1; then
        log_audio "⚠️  Cannot recover devices - user doesn't exist yet"
        return 1
    fi
    
    # Try to create virtual devices
    su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID:-1000}
        export PULSE_RUNTIME_PATH=/run/user/${DEV_UID:-1000}/pulse
        pactl load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description=\"Virtual_Marketing_Speaker\" 2>/dev/null || true
        pactl load-module module-null-sink sink_name=virtual_microphone sink_properties=device.description=\"Virtual_Marketing_Microphone\" 2>/dev/null || true
        pactl set-default-sink virtual_speaker 2>/dev/null || true
    " 2>/dev/null || log_audio "⚠️  Device recovery failed"
}

# Ensure PulseAudio routes audio through the virtual_speaker sink
ensure_default_sink() {
    if ! id "${DEV_USERNAME}" >/dev/null 2>&1; then
        return
    fi

    local current_sink
    current_sink=$(su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID:-1000}; pactl info 2>/dev/null | grep 'Default Sink' | awk -F ': ' '{print \$2}'" 2>/dev/null || echo "unknown")

    if [ "$current_sink" != "virtual_speaker" ]; then
        log_audio "⚠️  Default sink is $current_sink - resetting to virtual_speaker"
        su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID:-1000}; pactl set-default-sink virtual_speaker 2>/dev/null" || true
        # Move existing audio streams to virtual_speaker
        su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID:-1000}; pactl list short sink-inputs 2>/dev/null | awk '{print \$1}' | xargs -r -n1 pactl move-sink-input {} virtual_speaker 2>/dev/null" || true
    else
        log_audio "✅ Default sink correctly set to virtual_speaker"
    fi
}

check_kde_audio() {
    if pgrep -f "systemsettings5" >/dev/null || pgrep -f "knotify" >/dev/null; then
        log_audio "✅ KDE audio components are active"
        return 0
    else
        log_audio "⚠️  KDE audio components not detected"
        return 1
    fi
}

# Restart PulseAudio using available startup script or direct commands
restart_pulseaudio() {
    log_audio "\U0001F504 Restarting PulseAudio daemon"
    if command -v start-pulseaudio.sh >/dev/null 2>&1; then
        "$(command -v start-pulseaudio.sh)" >/dev/null 2>&1 || true
    else
        pkill -x pulseaudio >/dev/null 2>&1 || true
        if id "${DEV_USERNAME}" >/dev/null 2>&1; then
            su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID:-1000}; pulseaudio --start" >/dev/null 2>&1 || true
        else
            pulseaudio --start >/dev/null 2>&1 || true
        fi
    fi
}

# Continuously verify audio stream output and latency
monitor_audio_stream() {
    while true; do
        if ! id "${DEV_USERNAME}" >/dev/null 2>&1; then
            sleep 5
            continue
        fi

        local latency bytes
        latency=$(
            su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID:-1000}; pactl list sources 2>/dev/null" 2>/dev/null \
            | awk '/Name: virtual_speaker.monitor/{f=1} f && /Latency:/{sub(/^[ \t]*Latency: /, "", $0); print; exit}' \
            || echo ""
        )
        bytes=$(su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID:-1000}; timeout 3s parec --latency-msec=1 -d virtual_speaker.monitor 2>/dev/null | wc -c" 2>/dev/null || echo 0)

        if [ "$bytes" -gt 0 ]; then
            log_audio "\U0001F4E1 virtual_speaker.monitor active - ${bytes} bytes read (latency: ${latency:-unknown})"
        else
            log_audio "\U0001F6D1 virtual_speaker.monitor stalled - restarting PulseAudio"
            restart_pulseaudio
        fi

        sleep 5
    done
}

generate_audio_status() {
    log_audio "=== Audio System Status Report ==="
    
    # Check PulseAudio
    if check_pulseaudio; then
        # Check devices
        check_audio_devices
        
        # List available devices
        log_audio "Available audio sinks:"
        su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID:-1000}; pactl list short sinks 2>/dev/null" | while read -r line; do
            log_audio "  - $line"
        done
        
        log_audio "Available audio sources:"
        su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID:-1000}; pactl list short sources 2>/dev/null" | while read -r line; do
            log_audio "  - $line"
        done
    fi
    
    # Check KDE integration
    check_kde_audio
    
    # Check if test script is available
    if [ -f "/usr/local/bin/test-desktop-audio.sh" ]; then
        log_audio "✅ Desktop audio test script available"
    else
        log_audio "❌ Desktop audio test script missing"
    fi
    
    log_audio "=== Audio Status Report Complete ==="
}

main() {
    local command="${1:-status}"
    
    case "$command" in
        "status")
            generate_audio_status
            ;;
        "check")
            if check_pulseaudio && check_audio_devices; then
                log_audio "✅ Audio system is healthy"
                exit 0
            else
                log_audio "⚠️  Audio system needs attention but not critical"
                exit 0  # Don't exit with error to prevent supervisor restart loops
            fi
            ;;
        "monitor")
            log_audio "Starting continuous audio monitoring (10-minute intervals)..."
            monitor_audio_stream &
            STREAM_MONITOR_PID=$!
            trap "kill $STREAM_MONITOR_PID" EXIT
            while true; do
                # Only generate status if system is ready
                if id "${DEV_USERNAME}" >/dev/null 2>&1; then
                    generate_audio_status
                else
                    log_audio "⚠️  System not ready for audio monitoring yet"
                fi
                sleep 600  # Check every 10 minutes
            done
            ;;
        *)
            log_audio "Usage: $0 {status|check|monitor}"
            exit 1
            ;;
    esac
}

main "$@"
