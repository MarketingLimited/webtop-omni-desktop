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
    device_count=$(pactl list short sinks 2>/dev/null | wc -l)
    
    if [ "$device_count" -gt 0 ]; then
        log_audio "✅ Audio devices available: $device_count sinks"
        return 0
    else
        log_audio "❌ No audio devices available"
        return 1
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

generate_audio_status() {
    log_audio "=== Audio System Status Report ==="
    
    # Check PulseAudio
    if check_pulseaudio; then
        # Check devices
        check_audio_devices
        
        # List available devices
        log_audio "Available audio sinks:"
        pactl list short sinks 2>/dev/null | while read -r line; do
            log_audio "  - $line"
        done
        
        log_audio "Available audio sources:"
        pactl list short sources 2>/dev/null | while read -r line; do
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
                log_audio "❌ Audio system has issues"
                exit 1
            fi
            ;;
        "monitor")
            log_audio "Starting continuous audio monitoring..."
            while true; do
                generate_audio_status
                sleep 300  # Check every 5 minutes
            done
            ;;
        *)
            log_audio "Usage: $0 {status|check|monitor}"
            exit 1
            ;;
    esac
}

main "$@"