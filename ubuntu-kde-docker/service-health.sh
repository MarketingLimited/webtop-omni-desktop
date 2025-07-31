#!/bin/bash

# Service Health Check Script for Marketing Agency WebTop
# Provides service status monitoring and reporting

# Configuration
HEALTH_CHECK_INTERVAL=${HEALTH_CHECK_INTERVAL:-30}
LOG_FILE="/var/log/supervisor/service-health.log"

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

check_xpra() {
    pgrep -f "xpra.*14500" > /dev/null
}

check_pulseaudio() {
    pgrep -f "pulseaudio.*daemon" > /dev/null
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
    wait_for_service "PulseAudio" "check_pulseaudio" 30
    
    # Stage 4: Remote access services
    wait_for_service "VNC" "check_vnc" 30
    wait_for_service "noVNC" "check_novnc" 30
    
    # Stage 5: Optional services
    if wait_for_service "Xpra" "check_xpra" 30; then
        health_log "📡 Xpra remote access available on port 14500"
    fi
    
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
        "PulseAudio:check_pulseaudio"
        "VNC:check_vnc"
        "noVNC:check_novnc"
        "Xpra:check_xpra"
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
        "14500:Xpra Remote Desktop"
        "7681:TTYD Web Terminal"
        "22:SSH Server"
        "4713:PulseAudio TCP"
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
        *)
            echo "Usage: $0 {check|status|wait}"
            echo "  check  - Check service dependencies and wait for readiness"
            echo "  status - Generate service and port status report"
            echo "  wait   - Start in dependency wait mode"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"