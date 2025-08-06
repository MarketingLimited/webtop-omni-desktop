#!/bin/bash
# PipeWire Audio Monitor Script
# Monitors PipeWire and virtual device status

set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"
LOG_FILE="/var/log/supervisor/audio-monitor.log"

log_audio() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [AUDIO] $1" | tee -a "$LOG_FILE"
}

check_pipewire() {
    if pw-cli info >/dev/null 2>&1; then
        log_audio "✅ PipeWire daemon is running"
        return 0
    else
        log_audio "❌ PipeWire daemon is not running"
        return 1
    fi
}

ensure_default_devices() {
    export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
    local speaker_id mic_id
    speaker_id=$(wpctl status | grep -A1 'Sinks' | grep 'virtual_speaker' | awk '{print $2}' | tr -d '.')
    mic_id=$(wpctl status | grep -A1 'Sources' | grep 'virtual_microphone' | awk '{print $2}' | tr -d '.')
    [ -n "$speaker_id" ] && wpctl set-default "$speaker_id" >/dev/null 2>&1
    [ -n "$mic_id" ] && wpctl set-default "$mic_id" >/dev/null 2>&1
}

check_audio_devices() {
    export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
    if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
        log_audio "⚠️  User ${DEV_USERNAME} doesn't exist yet, skipping device check"
        return 1
    fi
    if wpctl status | grep -q 'virtual_speaker' && wpctl status | grep -q 'virtual_microphone'; then
        log_audio "✅ Virtual audio devices available"
        ensure_default_devices
        return 0
    else
        log_audio "⚠️  Virtual audio devices missing - attempting recovery"
        /usr/local/bin/create-virtual-pipewire-devices.sh >/dev/null 2>&1 || true
        return 1
    fi
}

generate_audio_status() {
    log_audio "=== PipeWire Audio Status Report ==="
    check_pipewire
    check_audio_devices
    log_audio "Available PipeWire nodes:"
    wpctl status | head -n 50 | while read -r line; do
        log_audio "  $line"
    done
    log_audio "=== Audio Status Report Complete ==="
}

main() {
    local command="${1:-status}"
    case "$command" in
        status)
            generate_audio_status
            ;;
        check)
            if check_pipewire && check_audio_devices; then
                log_audio "✅ Audio system is healthy"
                exit 0
            else
                log_audio "⚠️  Audio system needs attention"
                exit 0
            fi
            ;;
        monitor)
            log_audio "Starting continuous audio monitoring (10-minute intervals)..."
            while true; do
                if id "$DEV_USERNAME" >/dev/null 2>&1; then
                    generate_audio_status
                else
                    log_audio "⚠️  System not ready for audio monitoring yet"
                fi
                sleep 600
            done
            ;;
        *)
            log_audio "Usage: $0 {status|check|monitor}"
            exit 1
            ;;
    esac
}

main "$@"
