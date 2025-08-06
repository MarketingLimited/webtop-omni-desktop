#!/bin/bash
# Enhanced PipeWire Audio Monitor Script
# Monitors PipeWire and virtual device status with recovery capabilities

set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"
LOG_FILE="/var/log/supervisor/audio-monitor.log"
STATE_FILE="/tmp/audio-monitor-state.txt"

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

log_audio() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [AUDIO] $1" | tee -a "$LOG_FILE"
}

# Function to run commands as the dev user
run_as_user() {
    su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; $*"
}

check_pipewire() {
    if run_as_user "pw-cli info" >/dev/null 2>&1; then
        log_audio "✅ PipeWire daemon is running and accessible"
        return 0
    else
        log_audio "❌ PipeWire daemon is not running or not accessible"
        return 1
    fi
}

check_wireplumber() {
    if run_as_user "wpctl status" >/dev/null 2>&1; then
        log_audio "✅ WirePlumber is running and accessible"
        return 0
    else
        log_audio "❌ WirePlumber is not running or not accessible"
        return 1
    fi
}

check_pipewire_process() {
    if pgrep -f "pipewire" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

check_wireplumber_process() {
    if pgrep -f "wireplumber" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

ensure_default_devices() {
    if ! run_as_user "wpctl status" >/dev/null 2>&1; then
        log_audio "⚠️  WirePlumber not accessible, cannot set default devices"
        return 1
    fi
    
    local speaker_id mic_id
    speaker_id=$(run_as_user "wpctl status" 2>/dev/null | grep 'virtual_speaker' | head -1 | awk '{print $2}' | tr -d '.' | sed 's/[^0-9]//g')
    mic_id=$(run_as_user "wpctl status" 2>/dev/null | grep -A10 "Sources:" | grep "virtual_microphone.*monitor" | head -1 | awk '{print $2}' | tr -d '.' | sed 's/[^0-9]//g')
    
    if [ -n "$speaker_id" ]; then
        if run_as_user "wpctl set-default $speaker_id" >/dev/null 2>&1; then
            log_audio "✅ Set virtual_speaker as default sink (ID: $speaker_id)"
        else
            log_audio "⚠️  Failed to set virtual_speaker as default sink"
        fi
    fi
    
    if [ -n "$mic_id" ]; then
        if run_as_user "wpctl set-default $mic_id" >/dev/null 2>&1; then
            log_audio "✅ Set virtual_microphone monitor as default source (ID: $mic_id)"
        else
            log_audio "⚠️  Failed to set virtual_microphone monitor as default source"
        fi
    fi
}

check_audio_devices() {
    if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
        log_audio "⚠️  User ${DEV_USERNAME} doesn't exist yet, skipping device check"
        return 1
    fi
    
    local devices_found=true
    
    if run_as_user "pw-cli list-objects" 2>/dev/null | grep -q 'virtual_speaker'; then
        log_audio "✅ virtual_speaker found"
    else
        log_audio "❌ virtual_speaker missing"
        devices_found=false
    fi
    
    if run_as_user "pw-cli list-objects" 2>/dev/null | grep -q 'virtual_microphone'; then
        log_audio "✅ virtual_microphone found"
    else
        log_audio "❌ virtual_microphone missing"
        devices_found=false
    fi
    
    if [ "$devices_found" = true ]; then
        ensure_default_devices
        return 0
    else
        log_audio "⚠️  Virtual audio devices missing - attempting recovery"
        attempt_device_recovery
        return 1
    fi
}

attempt_device_recovery() {
    log_audio "🔧 Attempting virtual audio device recovery..."
    
    if [ -f "/usr/local/bin/create-virtual-pipewire-devices.sh" ]; then
        if /usr/local/bin/create-virtual-pipewire-devices.sh >/dev/null 2>&1; then
            log_audio "✅ Virtual device recovery successful"
            sleep 3
            ensure_default_devices
        else
            log_audio "❌ Virtual device recovery failed"
        fi
    else
        log_audio "❌ Virtual device creation script not found"
    fi
}

attempt_pipewire_recovery() {
    log_audio "🔧 Attempting PipeWire recovery..."
    
    if [ -f "/usr/local/bin/pipewire-recovery.sh" ]; then
        if /usr/local/bin/pipewire-recovery.sh recover; then
            log_audio "✅ PipeWire recovery successful"
            return 0
        else
            log_audio "❌ PipeWire recovery failed"
            return 1
        fi
    else
        log_audio "❌ PipeWire recovery script not found"
        return 1
    fi
}

restart_wireplumber() {
    log_audio "🔄 Attempting WirePlumber restart..."
    
    if command -v supervisorctl >/dev/null 2>&1; then
        if supervisorctl restart wireplumber 2>/dev/null; then
            log_audio "✅ WirePlumber restarted successfully"
            sleep 5
            return 0
        else
            log_audio "❌ Failed to restart WirePlumber via supervisorctl"
            return 1
        fi
    else
        log_audio "❌ supervisorctl not available"
        return 1
    fi
}

generate_audio_status() {
    log_audio "=== Enhanced PipeWire Audio Status Report ==="
    
    local pipewire_ok=true
    local wireplumber_ok=true
    local devices_ok=true
    
    # Check PipeWire process and functionality
    if check_pipewire_process; then
        log_audio "✅ PipeWire process is running"
        if check_pipewire; then
            log_audio "✅ PipeWire is functional"
        else
            log_audio "❌ PipeWire process running but not functional"
            pipewire_ok=false
        fi
    else
        log_audio "❌ PipeWire process is not running"
        pipewire_ok=false
    fi
    
    # Check WirePlumber process and functionality
    if check_wireplumber_process; then
        log_audio "✅ WirePlumber process is running"
        if check_wireplumber; then
            log_audio "✅ WirePlumber is functional"
        else
            log_audio "❌ WirePlumber process running but not functional"
            wireplumber_ok=false
        fi
    else
        log_audio "❌ WirePlumber process is not running"
        wireplumber_ok=false
    fi
    
    # Check audio devices
    if ! check_audio_devices; then
        devices_ok=false
    fi
    
    # Show detailed status if WirePlumber is working
    if [ "$wireplumber_ok" = true ]; then
        log_audio "Available PipeWire nodes:"
        run_as_user "wpctl status" 2>/dev/null | head -n 50 | while read -r line; do
            log_audio "  $line"
        done
    else
        log_audio "⚠️  Cannot show detailed status - WirePlumber not functional"
    fi
    
    # Overall health assessment
    if [ "$pipewire_ok" = true ] && [ "$wireplumber_ok" = true ] && [ "$devices_ok" = true ]; then
        log_audio "🎉 Audio system is fully healthy"
    else
        log_audio "⚠️  Audio system has issues that need attention"
    fi
    
    log_audio "=== Audio Status Report Complete ==="
}

comprehensive_health_check() {
    log_audio "🔍 Performing comprehensive audio health check..."
    
    local recovery_needed=false
    local recovery_attempted=false
    
    # Check and recover PipeWire
    if ! check_pipewire_process || ! check_pipewire; then
        log_audio "🚨 PipeWire issues detected"
        recovery_needed=true
        
        if attempt_pipewire_recovery; then
            recovery_attempted=true
            sleep 5  # Allow time for recovery
        fi
    fi
    
    # Check and recover WirePlumber
    if ! check_wireplumber_process || ! check_wireplumber; then
        log_audio "🚨 WirePlumber issues detected"
        recovery_needed=true
        
        if restart_wireplumber; then
            recovery_attempted=true
            sleep 5  # Allow time for recovery
        fi
    fi
    
    # Check and recover virtual devices
    if ! check_audio_devices; then
        log_audio "🚨 Virtual audio device issues detected"
        recovery_needed=true
        recovery_attempted=true  # attempt_device_recovery is called within check_audio_devices
    fi
    
    # Final status check
    if [ "$recovery_attempted" = true ]; then
        log_audio "🔄 Re-checking audio system after recovery attempts..."
        sleep 3
        generate_audio_status
    fi
    
    if [ "$recovery_needed" = false ]; then
        log_audio "✅ Audio system is healthy - no recovery needed"
        return 0
    elif [ "$recovery_attempted" = true ]; then
        log_audio "🔧 Recovery attempts completed - check logs for results"
        return 0
    else
        log_audio "❌ Audio system issues detected but recovery failed"
        return 1
    fi
}

intelligent_monitor() {
    log_audio "🚀 Starting intelligent audio monitoring with proactive recovery..."
    
    local monitor_interval=300  # 5 minutes
    local failure_count=0
    local max_failures=3
    local last_recovery_time=0
    local recovery_cooldown=1800  # 30 minutes
    
    while true; do
        if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
            log_audio "⚠️  System not ready for audio monitoring yet"
            sleep 60
            continue
        fi
        
        local current_time=$(date +%s)
        local system_healthy=true
        
        # Quick health checks
        if ! check_pipewire || ! check_wireplumber || ! check_audio_devices; then
            system_healthy=false
            failure_count=$((failure_count + 1))
            log_audio "⚠️  Audio system issues detected (failure count: $failure_count)"
        else
            if [ $failure_count -gt 0 ]; then
                log_audio "✅ Audio system recovered (resetting failure count)"
                failure_count=0
            fi
        fi
        
        # Attempt recovery if needed
        if [ "$system_healthy" = false ] && [ $failure_count -ge $max_failures ]; then
            local time_since_recovery=$((current_time - last_recovery_time))
            
            if [ $time_since_recovery -ge $recovery_cooldown ]; then
                log_audio "🔧 Attempting proactive audio recovery (cooldown expired)..."
                comprehensive_health_check
                last_recovery_time=$current_time
                failure_count=0
            else
                local remaining_cooldown=$((recovery_cooldown - time_since_recovery))
                log_audio "⏳ Recovery in cooldown, ${remaining_cooldown}s remaining"
            fi
        fi
        
        # Periodic detailed status (every 6 cycles = 30 minutes)
        local cycle_count_file="/tmp/audio-monitor-cycles"
        local cycle_count=0
        if [ -f "$cycle_count_file" ]; then
            cycle_count=$(cat "$cycle_count_file")
        fi
        cycle_count=$((cycle_count + 1))
        echo "$cycle_count" > "$cycle_count_file"
        
        if [ $((cycle_count % 6)) -eq 0 ]; then
            log_audio "📊 Periodic detailed status report (cycle $cycle_count)..."
            generate_audio_status
        fi
        
        sleep $monitor_interval
    done
}

main() {
    local command="${1:-status}"
    case "$command" in
        status)
            generate_audio_status
            ;;
        check)
            if comprehensive_health_check; then
                log_audio "✅ Audio system health check completed"
                exit 0
            else
                log_audio "⚠️  Audio system health check found issues"
                exit 1
            fi
            ;;
        monitor)
            log_audio "Starting basic continuous audio monitoring (10-minute intervals)..."
            while true; do
                if id "$DEV_USERNAME" >/dev/null 2>&1; then
                    generate_audio_status
                else
                    log_audio "⚠️  System not ready for audio monitoring yet"
                fi
                sleep 600
            done
            ;;
        intelligent-monitor)
            intelligent_monitor
            ;;
        recover)
            comprehensive_health_check
            ;;
        *)
            log_audio "Usage: $0 {status|check|monitor|intelligent-monitor|recover}"
            log_audio "  status              - Generate audio status report"
            log_audio "  check               - Perform health check with recovery"
            log_audio "  monitor             - Basic continuous monitoring"
            log_audio "  intelligent-monitor - Smart monitoring with proactive recovery"
            log_audio "  recover             - Force recovery attempt"
            exit 1
            ;;
    esac
}

main "$@"
