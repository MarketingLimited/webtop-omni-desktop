#!/bin/bash

# Service Health Check and Dependency Management Script
# Marketing Agency WebTop Container

set -e

echo "🔍 Service Health Check and Dependency Manager..."

# Configuration
HEALTH_CHECK_INTERVAL=5
MAX_WAIT_TIME=60
LOG_FILE="/var/log/supervisor/health-checks.log"

# Logging function
health_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [HEALTH] $*" | tee -a "$LOG_FILE"
}

# Wait for service function
wait_for_service() {
    local service_name="$1"
    local check_command="$2"
    local max_wait="${3:-30}"
    local wait_time=0
    
    health_log "Waiting for $service_name to be ready..."
    
    while [ $wait_time -lt $max_wait ]; do
        if eval "$check_command" 2>/dev/null; then
            health_log "✅ $service_name is ready"
            return 0
        fi
        sleep "$HEALTH_CHECK_INTERVAL"
        wait_time=$((wait_time + HEALTH_CHECK_INTERVAL))
        health_log "⏳ Waiting for $service_name... ($wait_time/$max_wait seconds)"
    done
    
    health_log "❌ $service_name failed to become ready within $max_wait seconds"
    return 1
}

# Service health checks
check_xvfb() {
    pgrep -f "Xvfb :1" > /dev/null
}

check_dbus() {
    [ -S /run/dbus/system_bus_socket ] && pgrep -f "dbus-daemon --system" > /dev/null
}

check_kde() {
    pgrep -f "startplasma-x11" > /dev/null && \
    DISPLAY=:1 xdpyinfo > /dev/null 2>&1
}

check_pulseaudio() {
    pgrep -f "pulseaudio.*--daemonize=no" > /dev/null
}

check_vnc() {
    pgrep -f "x11vnc.*:1" > /dev/null && \
    netstat -tuln | grep -q ":5901 "
}

check_novnc() {
    pgrep -f "websockify.*80" > /dev/null && \
    netstat -tuln | grep -q ":80 "
}

check_xpra() {
    pgrep -f "xpra.*14500" > /dev/null && \
    netstat -tuln | grep -q ":14500 "
}

check_ttyd() {
    pgrep -f "ttyd.*7681" > /dev/null && \
    netstat -tuln | grep -q ":7681 "
}

# Service dependency checker
check_service_dependencies() {
    health_log "🔍 Checking service dependencies..."
    
    # Stage 1: Core X11 and D-Bus
    wait_for_service "Xvfb" "check_xvfb" 30 || return 1
    wait_for_service "D-Bus" "check_dbus" 20 || return 1
    
    # Stage 2: Audio (can run in parallel)
    wait_for_service "PulseAudio" "check_pulseaudio" 30 || health_log "⚠️  PulseAudio not ready, continuing..."
    
    # Stage 3: Desktop Environment
    wait_for_service "KDE" "check_kde" 45 || return 1
    
    # Stage 4: Remote Access Services
    wait_for_service "VNC" "check_vnc" 30 || health_log "⚠️  VNC not ready"
    wait_for_service "noVNC" "check_novnc" 20 || health_log "⚠️  noVNC not ready"
    wait_for_service "Xpra" "check_xpra" 30 || health_log "⚠️  Xpra not ready"
    wait_for_service "TTYD" "check_ttyd" 25 || health_log "⚠️  TTYD not ready"
    
    health_log "✅ Service dependency check completed"
    return 0
}

# Generate service status report
generate_status_report() {
    health_log "📊 Service Status Report:"
    
    local services=(
        "Xvfb:check_xvfb"
        "D-Bus:check_dbus"  
        "PulseAudio:check_pulseaudio"
        "KDE:check_kde"
        "VNC:check_vnc"
        "noVNC:check_novnc"
        "Xpra:check_xpra"
        "TTYD:check_ttyd"
    )
    
    for service_check in "${services[@]}"; do
        local service_name="${service_check%:*}"
        local check_func="${service_check#*:}"
        
        if eval "$check_func" 2>/dev/null; then
            health_log "  ✅ $service_name: Running"
        else
            health_log "  ❌ $service_name: Not running"
        fi
    done
}

# Create port status report
check_port_status() {
    health_log "🔌 Port Status Report:"
    
    local ports=(
        "80:noVNC Web Interface"
        "5901:VNC Server"
        "7681:TTYD Terminal"
        "14500:Xpra Server"
        "4713:PulseAudio"
        "22:SSH"
    )
    
    for port_desc in "${ports[@]}"; do
        local port="${port_desc%:*}"
        local desc="${port_desc#*:}"
        
        if netstat -tuln | grep -q ":$port "; then
            health_log "  ✅ Port $port ($desc): Listening"
        else
            health_log "  ❌ Port $port ($desc): Not listening"
        fi
    done
}

# Main execution
case "${1:-check}" in
    "check")
        check_service_dependencies
        ;;
    "status")
        generate_status_report
        check_port_status
        ;;
    "wait")
        health_log "🕐 Starting dependency wait mode..."
        check_service_dependencies
        ;;
    *)
        health_log "Usage: $0 {check|status|wait}"
        exit 1
        ;;
esac