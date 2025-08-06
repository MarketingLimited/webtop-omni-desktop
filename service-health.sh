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

check_ttyd() {
    pgrep -f "ttyd.*7681" > /dev/null
}

check_ssh() {
    pgrep -f "sshd.*daemon" > /dev/null
}

# Service dependency checking
check_service_dependencies() {
    health_log "🔍 Starting service dependency check..."
    
    # Stage 1: Core services
    wait_for_service "Xvfb" "check_xvfb" 30
    wait_for_service "D-Bus" "check_dbus" 30
    
    # Stage 2: Desktop environment
    wait_for_service "KDE Plasma" "check_kde" 60
    
    # Stage 3: Audio system
    wait_for_service "PipeWire" "check_pipewire" 30
    
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
    
    health_log "✅ Service dependency check completed"
}

# Service status reporting
generate_status_report() {
    health_log "📊 Generating service status report..."
    
    local services=(
        "supervisord:pgrep -f supervisord"
        "Xvfb:check_xvfb"
        "D-Bus:check_dbus"
        "KDE:check_kde"
        "PipeWire:check_pipewire"
        "VNC:check_vnc"
        "noVNC:check_novnc"
        "TTYD:check_ttyd"
        "SSH:check_ssh"
    )
    
    for service_info in "${services[@]}"; do
        local service_name="${service_info%%:*}"
        local check_cmd="${service_info##*:}"
        
        if eval "$check_cmd" > /dev/null 2>&1; then
            health_log "✅ $service_name: RUNNING"
        else
            health_log "❌ $service_name: NOT RUNNING"
        fi
    done
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

# Smart monitoring with state tracking
smart_monitor() {
    health_log "🚀 Starting smart health monitoring..."
    
    local current_state=""
    local last_state=""
    local monitor_cycle=0
    
    while true; do
        current_state=$(generate_service_state_hash)
        
        if [ -f "$STATE_FILE" ]; then
            last_state=$(cat "$STATE_FILE")
        fi
        
        # Only report if state changed or every 10th cycle (for heartbeat)
        if [ "$current_state" != "$last_state" ] || [ $((monitor_cycle % 10)) -eq 0 ]; then
            if [ "$current_state" != "$last_state" ]; then
                health_log "📊 Service state changed, generating report..."
            else
                health_log "💓 Health monitoring heartbeat (cycle $monitor_cycle)"
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