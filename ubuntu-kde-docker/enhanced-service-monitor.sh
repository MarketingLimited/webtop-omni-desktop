#!/bin/bash
# Enhanced Service Monitor with Auto-Recovery
# Replaces basic service monitoring with intelligent recovery mechanisms

set -euo pipefail

LOG_FILE="/var/log/supervisor/enhanced-service-monitor.log"
mkdir -p "$(dirname "$LOG_FILE")"

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"

# Configuration
MONITOR_INTERVAL="${MONITOR_INTERVAL:-60}"
MAX_RECOVERY_ATTEMPTS=3
RECOVERY_COOLDOWN=300  # 5 minutes between recovery attempts

# State tracking
declare -A service_failures
declare -A last_recovery_time

log_message() {
    local message="$1"
    local level="${2:-INFO}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] [MONITOR] $message" | tee -a "$LOG_FILE"
}

# Enhanced D-Bus health check with recovery
check_dbus_health() {
    local service="dbus"
    
    # Check if D-Bus socket exists
    if [ ! -S /run/dbus/system_bus_socket ]; then
        log_message "D-Bus socket missing" "ERROR"
        return 1
    fi
    
    # Check if D-Bus is responsive
    if ! dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetId >/dev/null 2>&1; then
        log_message "D-Bus not responsive" "ERROR"
        return 1
    fi
    
    # Check if D-Bus process is running
    if ! pgrep -x dbus-daemon >/dev/null; then
        log_message "D-Bus daemon process not found" "ERROR"
        return 1
    fi
    
    return 0
}

# PulseAudio health check with user context
check_pulseaudio_health() {
    local service="pulseaudio"
    
    # Skip if user doesn't exist
    if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
        return 0
    fi
    
    # Check if PulseAudio is running
    if ! pgrep -x pulseaudio >/dev/null; then
        log_message "PulseAudio daemon not running" "WARN"
        return 1
    fi
    
    # Check if PulseAudio is accessible
    if ! su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl info >/dev/null 2>&1"; then
        log_message "PulseAudio not accessible to user" "WARN"
        return 1
    fi
    
    return 0
}

# VNC service health check
check_vnc_health() {
    local service="kasmvnc"
    
    # Check if VNC port is listening
    if ! nc -z localhost 5901 2>/dev/null; then
        log_message "VNC service not listening on port 5901" "WARN"
        return 1
    fi
    
    # Check if KasmVNC process is running
    if ! pgrep -f "kasmvnc\|vncserver" >/dev/null; then
        log_message "VNC server process not found" "WARN"
        return 1
    fi
    
    return 0
}

# Service recovery mechanism
recover_service() {
    local service="$1"
    local current_time
    current_time=$(date +%s)
    
    # Check cooldown period
    if [ -n "${last_recovery_time[$service]:-}" ]; then
        local time_since_recovery=$((current_time - last_recovery_time[$service]))
        if [ $time_since_recovery -lt $RECOVERY_COOLDOWN ]; then
            log_message "Service $service in recovery cooldown ($time_since_recovery/$RECOVERY_COOLDOWN seconds)" "INFO"
            return 1
        fi
    fi
    
    # Check failure count
    local failures=${service_failures[$service]:-0}
    if [ $failures -ge $MAX_RECOVERY_ATTEMPTS ]; then
        log_message "Service $service exceeded max recovery attempts ($failures/$MAX_RECOVERY_ATTEMPTS)" "ERROR"
        return 1
    fi
    
    log_message "Attempting recovery for service: $service (attempt $((failures + 1))/$MAX_RECOVERY_ATTEMPTS)" "INFO"
    
    case "$service" in
        "dbus")
            # D-Bus recovery requires supervisor restart
            if supervisorctl restart dbus 2>/dev/null; then
                log_message "D-Bus service restarted via supervisor" "INFO"
                sleep 5  # Give D-Bus time to stabilize
                return 0
            else
                log_message "Failed to restart D-Bus service" "ERROR"
                return 1
            fi
            ;;
        "pulseaudio")
            # PulseAudio recovery
            if supervisorctl restart pulseaudio 2>/dev/null; then
                log_message "PulseAudio service restarted via supervisor" "INFO"
                return 0
            else
                log_message "Failed to restart PulseAudio service" "ERROR"
                return 1
            fi
            ;;
        "kasmvnc")
            # VNC recovery
            if supervisorctl restart kasmvnc 2>/dev/null; then
                log_message "VNC service restarted via supervisor" "INFO"
                return 0
            else
                log_message "Failed to restart VNC service" "ERROR"
                return 1
            fi
            ;;
        *)
            log_message "Unknown service for recovery: $service" "ERROR"
            return 1
            ;;
    esac
}

# Update service state tracking
update_service_state() {
    local service="$1"
    local status="$2"
    local current_time
    current_time=$(date +%s)
    
    if [ "$status" = "healthy" ]; then
        # Reset failure count on successful health check
        service_failures[$service]=0
    else
        # Increment failure count
        local current_failures=${service_failures[$service]:-0}
        service_failures[$service]=$((current_failures + 1))
        
        # Attempt recovery
        if recover_service "$service"; then
            last_recovery_time[$service]=$current_time
            log_message "Service $service recovery completed" "INFO"
        else
            log_message "Service $service recovery failed" "ERROR"
        fi
    fi
}

# Main monitoring loop
monitor_services() {
    log_message "Enhanced service monitor started (interval: ${MONITOR_INTERVAL}s)"
    
    local services=(
        "dbus:check_dbus_health"
        "pulseaudio:check_pulseaudio_health"
        "kasmvnc:check_vnc_health"
    )
    
    while true; do
        log_message "=== Service Health Check Cycle ==="
        
        for service_def in "${services[@]}"; do
            local service_name="${service_def%%:*}"
            local check_function="${service_def##*:}"
            
            if $check_function; then
                log_message "Service $service_name: HEALTHY"
                update_service_state "$service_name" "healthy"
            else
                log_message "Service $service_name: UNHEALTHY"
                update_service_state "$service_name" "unhealthy"
            fi
        done
        
        # Report overall system health
        local total_failures=0
        for service in "${!service_failures[@]}"; do
            total_failures=$((total_failures + service_failures[$service]))
        done
        
        if [ $total_failures -eq 0 ]; then
            log_message "Overall system health: GOOD"
        else
            log_message "Overall system health: DEGRADED (total failures: $total_failures)"
        fi
        
        log_message "=== End Health Check Cycle ==="
        sleep "$MONITOR_INTERVAL"
    done
}

# Handle script termination
cleanup() {
    log_message "Enhanced service monitor shutting down"
    exit 0
}

trap cleanup TERM INT

# Main execution
main() {
    local command="${1:-monitor}"
    
    case "$command" in
        "monitor")
            monitor_services
            ;;
        "check")
            # Single health check
            if check_dbus_health && check_pulseaudio_health && check_vnc_health; then
                log_message "All services healthy"
                exit 0
            else
                log_message "Some services need attention"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 {monitor|check}"
            exit 1
            ;;
    esac
}

main "$@"