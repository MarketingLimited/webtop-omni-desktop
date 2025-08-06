#!/bin/bash

# Service Health Check Script for Marketing Agency WebTop
# Provides service status monitoring and reporting

# Configuration
HEALTH_CHECK_INTERVAL=${HEALTH_CHECK_INTERVAL:-300}
LOG_FILE="/var/log/supervisor/service-health.log"
STATE_FILE="/tmp/service-health-state.txt"
LAST_REPORT_FILE="/tmp/last-health-report.txt"

# Utility functions
health_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SERVICE-HEALTH] $1" | tee -a "$LOG_FILE"
}

wait_for_service() {
    local service_name="$1"
    local check_command="$2"
    local timeout="${3:-60}"
    local counter=0
    
    health_log "⏳ Waiting for $service_name to be ready..."
    
    while ! eval "$check_command" && [ $counter -lt $timeout ]; do
        sleep 2
        counter=$((counter + 2))
        health_log "   Still waiting for $service_name... (${counter}s)"
    done
    
    if eval "$check_command"; then
        health_log "✅ $service_name is ready"
        return 0
    else
        health_log "❌ $service_name failed to start within ${timeout}s"
        return 1
    fi
}

# Service check functions
check_xvfb() {
    pgrep -f "Xvfb.*:1" > /dev/null
}

check_dbus() {
    pgrep -f "dbus.*system" > /dev/null && [ -S /var/run/dbus/system_bus_socket ]
}

check_kde() {
    pgrep -f "startplasma" > /dev/null || pgrep -f "plasmashell" > /dev/null
}

check_vnc() {
    pgrep -f "x11vnc.*:1" > /dev/null
}

check_novnc() {
    pgrep -f "websockify.*80.*:5901" > /dev/null
}


check_pipewire() {
    pgrep -f "pipewire" >/dev/null 2>&1
}

check_wireplumber() {
    pgrep -f "wireplumber" >/dev/null 2>&1
}

check_pipewire_functional() {
    local DEV_USERNAME="${DEV_USERNAME:-devuser}"
    local DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"
    su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pw-cli info" >/dev/null 2>&1
}

check_wireplumber_functional() {
    local DEV_USERNAME="${DEV_USERNAME:-devuser}"
    local DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"
    su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; wpctl status" >/dev/null 2>&1
}

check_virtual_audio_devices() {
    local DEV_USERNAME="${DEV_USERNAME:-devuser}"
    local DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"
    su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pw-cli list-objects" 2>/dev/null | grep -q "virtual_speaker\|virtual_microphone"
}

check_ttyd() {
    pgrep -f "ttyd.*7681" > /dev/null
}

check_ssh() {
    pgrep -f "sshd.*daemon" > /dev/null
}

# Service recovery functions
recover_pipewire() {
    health_log "🔧 Attempting PipeWire recovery..."
    if [ -f "/usr/local/bin/pipewire-recovery.sh" ]; then
        if /usr/local/bin/pipewire-recovery.sh recover; then
            health_log "✅ PipeWire recovery successful"
            return 0
        else
            health_log "❌ PipeWire recovery failed"
            return 1
        fi
    else
        health_log "❌ PipeWire recovery script not found"
        return 1
    fi
}

recover_virtual_audio_devices() {
    health_log "🎧 Attempting virtual audio device recovery..."
    if [ -f "/usr/local/bin/create-virtual-pipewire-devices.sh" ]; then
        if /usr/local/bin/create-virtual-pipewire-devices.sh; then
            health_log "✅ Virtual audio device recovery successful"
            return 0
        else
            health_log "❌ Virtual audio device recovery failed"
            return 1
        fi
    else
        health_log "❌ Virtual audio device creation script not found"
        return 1
    fi
}

restart_service_via_supervisor() {
    local service_name="$1"
    health_log "🔄 Restarting $service_name via supervisorctl..."
    
    if command -v supervisorctl >/dev/null 2>&1; then
        if supervisorctl restart "$service_name" 2>/dev/null; then
            health_log "✅ Successfully restarted $service_name"
            sleep 5  # Give service time to start
            return 0
        else
            health_log "❌ Failed to restart $service_name via supervisorctl"
            return 1
        fi
    else
        health_log "❌ supervisorctl not available"
        return 1
    fi
}

# Enhanced service dependency checking with recovery
check_service_dependencies() {
    health_log "🔍 Starting enhanced service dependency check with recovery..."
    
    local recovery_attempts=0
    local max_recovery_attempts=2
    
    # Stage 1: Core services
    wait_for_service "Xvfb" "check_xvfb" 30
    wait_for_service "D-Bus" "check_dbus" 30
    
    # Stage 2: Desktop environment
    wait_for_service "KDE Plasma" "check_kde" 60
    
    # Stage 3: Audio system with recovery
    if ! wait_for_service "PipeWire" "check_pipewire" 30; then
        health_log "⚠️  PipeWire not running, attempting recovery..."
        if recover_pipewire; then
            wait_for_service "PipeWire" "check_pipewire" 30
        fi
    fi
    
    # Check PipeWire functionality
    if check_pipewire && ! check_pipewire_functional; then
        health_log "⚠️  PipeWire running but not functional, attempting recovery..."
        recover_pipewire
    fi
    
    # Check WirePlumber
    if ! wait_for_service "WirePlumber" "check_wireplumber" 30; then
        health_log "⚠️  WirePlumber not running, attempting restart..."
        restart_service_via_supervisor "wireplumber"
        wait_for_service "WirePlumber" "check_wireplumber" 30
    fi
    
    # Check WirePlumber functionality
    if check_wireplumber && ! check_wireplumber_functional; then
        health_log "⚠️  WirePlumber running but not functional, attempting restart..."
        restart_service_via_supervisor "wireplumber"
    fi
    
    # Check virtual audio devices
    if ! check_virtual_audio_devices; then
        health_log "⚠️  Virtual audio devices missing, attempting recovery..."
        recover_virtual_audio_devices
    fi
    
    # Stage 4: Remote access services
    wait_for_service "VNC" "check_vnc" 30
    wait_for_service "noVNC" "check_novnc" 30
    
    # Stage 5: Optional services
    if wait_for_service "TTYD" "check_ttyd" 30; then
        health_log "💻 Web terminal available on port 7681"
    fi
    
    if wait_for_service "SSH" "check_ssh" 30; then
        health_log "🔑 SSH access available on port 22"
    fi
    
    health_log "✅ Enhanced service dependency check completed"
}

# Enhanced service status reporting with functionality checks
generate_status_report() {
    health_log "📊 Generating enhanced service status report..."
    
    local services=(
        "supervisord:pgrep -f supervisord"
        "Xvfb:check_xvfb"
        "D-Bus:check_dbus"
        "KDE:check_kde"
        "PipeWire:check_pipewire"
        "WirePlumber:check_wireplumber"
        "VNC:check_vnc"
        "noVNC:check_novnc"
        "TTYD:check_ttyd"
        "SSH:check_ssh"
    )
    
    local failed_services=()
    local warning_services=()
    
    for service_info in "${services[@]}"; do
        local service_name="${service_info%%:*}"
        local check_cmd="${service_info##*:}"
        
        if eval "$check_cmd" > /dev/null 2>&1; then
            health_log "✅ $service_name: RUNNING"
            
            # Additional functionality checks for critical services
            case "$service_name" in
                "PipeWire")
                    if ! check_pipewire_functional; then
                        health_log "⚠️  $service_name: RUNNING but NOT FUNCTIONAL"
                        warning_services+=("$service_name")
                    else
                        health_log "✅ $service_name: FUNCTIONAL"
                    fi
                    ;;
                "WirePlumber")
                    if ! check_wireplumber_functional; then
                        health_log "⚠️  $service_name: RUNNING but NOT FUNCTIONAL"
                        warning_services+=("$service_name")
                    else
                        health_log "✅ $service_name: FUNCTIONAL"
                    fi
                    ;;
            esac
        else
            health_log "❌ $service_name: NOT RUNNING"
            failed_services+=("$service_name")
        fi
    done
    
    # Check virtual audio devices
    if check_virtual_audio_devices; then
        health_log "✅ Virtual Audio Devices: PRESENT"
    else
        health_log "❌ Virtual Audio Devices: MISSING"
        warning_services+=("Virtual Audio Devices")
    fi
    
    # Summary
    if [ ${#failed_services[@]} -eq 0 ] && [ ${#warning_services[@]} -eq 0 ]; then
        health_log "🎉 All services are running and functional"
    else
        if [ ${#failed_services[@]} -gt 0 ]; then
            health_log "🚨 Failed services: ${failed_services[*]}"
        fi
        if [ ${#warning_services[@]} -gt 0 ]; then
            health_log "⚠️  Services with issues: ${warning_services[*]}"
        fi
    fi
}

# Port status checking
check_port_status() {
    health_log "🌐 Checking port status..."
    
    local ports=(
        "80:noVNC Web Interface"
        "5901:VNC Server"
        "7681:TTYD Web Terminal"
        "22:SSH Server"
        "8080:WebRTC Bridge"
        "8081:WebRTC Signaling"
    )
    
    for port_info in "${ports[@]}"; do
        local port="${port_info%%:*}"
        local description="${port_info##*:}"
        
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            health_log "✅ Port $port ($description): LISTENING"
        else
            health_log "❌ Port $port ($description): NOT LISTENING"
        fi
    done
}

# Smart monitoring with proactive recovery
smart_monitor() {
    health_log "🚀 Starting smart health monitoring with proactive recovery..."
    
    local current_state=""
    local last_state=""
    local monitor_cycle=0
    local consecutive_failures=0
    local max_consecutive_failures=3
    local last_recovery_time=0
    local recovery_cooldown=1800  # 30 minutes
    
    while true; do
        current_state=$(generate_service_state_hash)
        
        if [ -f "$STATE_FILE" ]; then
            last_state=$(cat "$STATE_FILE")
        fi
        
        # Check for service failures and attempt recovery
        local current_time=$(date +%s)
        local needs_recovery=false
        
        # Check critical services
        if ! check_pipewire || ! check_pipewire_functional; then
            health_log "🚨 PipeWire issue detected"
            needs_recovery=true
        fi
        
        if ! check_wireplumber || ! check_wireplumber_functional; then
            health_log "🚨 WirePlumber issue detected"
            needs_recovery=true
        fi
        
        if ! check_virtual_audio_devices; then
            health_log "🚨 Virtual audio devices missing"
            needs_recovery=true
        fi
        
        # Attempt recovery if needed and not in cooldown
        if [ "$needs_recovery" = true ]; then
            consecutive_failures=$((consecutive_failures + 1))
            health_log "⚠️  Service issues detected (failure count: $consecutive_failures)"
            
            if [ $consecutive_failures -ge $max_consecutive_failures ]; then
                local time_since_recovery=$((current_time - last_recovery_time))
                
                if [ $time_since_recovery -ge $recovery_cooldown ]; then
                    health_log "🔧 Attempting proactive recovery (cooldown expired)..."
                    
                    # Attempt PipeWire recovery
                    if ! check_pipewire_functional; then
                        recover_pipewire
                    fi
                    
                    # Attempt WirePlumber restart
                    if ! check_wireplumber_functional; then
                        restart_service_via_supervisor "wireplumber"
                    fi
                    
                    # Attempt virtual device recovery
                    if ! check_virtual_audio_devices; then
                        recover_virtual_audio_devices
                    fi
                    
                    last_recovery_time=$current_time
                    consecutive_failures=0
                    health_log "✅ Proactive recovery attempt completed"
                else
                    local remaining_cooldown=$((recovery_cooldown - time_since_recovery))
                    health_log "⏳ Recovery in cooldown, ${remaining_cooldown}s remaining"
                fi
            fi
        else
            # Reset failure counter if services are healthy
            if [ $consecutive_failures -gt 0 ]; then
                health_log "✅ Services recovered, resetting failure counter"
                consecutive_failures=0
            fi
        fi
        
        # Report status changes or periodic heartbeat
        if [ "$current_state" != "$last_state" ] || [ $((monitor_cycle % 10)) -eq 0 ]; then
            if [ "$current_state" != "$last_state" ]; then
                health_log "📊 Service state changed, generating report..."
            else
                health_log "💓 Health monitoring heartbeat (cycle $monitor_cycle, failures: $consecutive_failures)"
            fi
            
            generate_status_report
            check_port_status
            echo "$current_state" > "$STATE_FILE"
        fi
        
        monitor_cycle=$((monitor_cycle + 1))
        sleep "$HEALTH_CHECK_INTERVAL"
    done
}

# Generate hash of current service states
generate_service_state_hash() {
    local services=(
        "supervisord:pgrep -f supervisord"
        "Xvfb:check_xvfb"
        "D-Bus:check_dbus"
        "KDE:check_kde"
        "PipeWire:check_pipewire"
        "WirePlumber:check_wireplumber"
        "VNC:check_vnc"
        "noVNC:check_novnc"
        "TTYD:check_ttyd"
        "SSH:check_ssh"
    )
    
    local state_string=""
    for service_info in "${services[@]}"; do
        local check_cmd="${service_info##*:}"
        if eval "$check_cmd" > /dev/null 2>&1; then
            state_string="${state_string}1"
        else
            state_string="${state_string}0"
        fi
    done
    
    # Add functional checks for critical services
    if check_pipewire_functional; then
        state_string="${state_string}1"
    else
        state_string="${state_string}0"
    fi
    
    if check_wireplumber_functional; then
        state_string="${state_string}1"
    else
        state_string="${state_string}0"
    fi
    
    if check_virtual_audio_devices; then
        state_string="${state_string}1"
    else
        state_string="${state_string}0"
    fi
    
    echo "$state_string" | md5sum | cut -d' ' -f1
}

# Main execution logic
main() {
    case "${1:-status}" in
        "check")
            check_service_dependencies
            ;;
        "status")
            generate_status_report
            check_port_status
            ;;
        "wait")
            health_log "🚀 Starting service health monitoring..."
            check_service_dependencies
            ;;
        "smart-monitor")
            smart_monitor
            ;;
        *)
            echo "Usage: $0 {check|status|wait|smart-monitor}"
            echo "  check        - Check service dependencies and wait for readiness"
            echo "  status       - Generate service and port status report"
            echo "  wait         - Start in dependency wait mode"
            echo "  smart-monitor - Start intelligent monitoring with state tracking"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"