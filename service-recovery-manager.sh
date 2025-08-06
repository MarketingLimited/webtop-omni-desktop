#!/bin/bash
# Service Recovery Manager
# Centralized service recovery and monitoring system

set -euo pipefail

# Configuration
RECOVERY_LOG="/var/log/supervisor/service-recovery.log"
STATE_DIR="/tmp/service-recovery"
COOLDOWN_FILE="$STATE_DIR/recovery-cooldowns"
FAILURE_COUNT_FILE="$STATE_DIR/failure-counts"

# Service configuration
DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

# Recovery settings
DEFAULT_COOLDOWN=1800  # 30 minutes
MAX_FAILURES=3
RECOVERY_TIMEOUT=300   # 5 minutes

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

# Logging function
log_recovery() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [RECOVERY] $*" | tee -a "$RECOVERY_LOG"
}

# Initialize state directory
init_state_dir() {
    mkdir -p "$STATE_DIR"
    touch "$COOLDOWN_FILE" "$FAILURE_COUNT_FILE"
}

# Get failure count for a service
get_failure_count() {
    local service="$1"
    grep "^$service:" "$FAILURE_COUNT_FILE" 2>/dev/null | cut -d: -f2 || echo "0"
}

# Set failure count for a service
set_failure_count() {
    local service="$1"
    local count="$2"
    
    # Remove existing entry
    grep -v "^$service:" "$FAILURE_COUNT_FILE" > "$FAILURE_COUNT_FILE.tmp" 2>/dev/null || true
    
    # Add new entry
    echo "$service:$count" >> "$FAILURE_COUNT_FILE.tmp"
    mv "$FAILURE_COUNT_FILE.tmp" "$FAILURE_COUNT_FILE"
}

# Get last recovery time for a service
get_last_recovery_time() {
    local service="$1"
    grep "^$service:" "$COOLDOWN_FILE" 2>/dev/null | cut -d: -f2 || echo "0"
}

# Set last recovery time for a service
set_last_recovery_time() {
    local service="$1"
    local timestamp="$2"
    
    # Remove existing entry
    grep -v "^$service:" "$COOLDOWN_FILE" > "$COOLDOWN_FILE.tmp" 2>/dev/null || true
    
    # Add new entry
    echo "$service:$timestamp" >> "$COOLDOWN_FILE.tmp"
    mv "$COOLDOWN_FILE.tmp" "$COOLDOWN_FILE"
}

# Check if service is in cooldown
is_in_cooldown() {
    local service="$1"
    local cooldown_duration="${2:-$DEFAULT_COOLDOWN}"
    local current_time=$(date +%s)
    local last_recovery=$(get_last_recovery_time "$service")
    local time_since_recovery=$((current_time - last_recovery))
    
    if [ $time_since_recovery -lt $cooldown_duration ]; then
        return 0  # In cooldown
    else
        return 1  # Not in cooldown
    fi
}

# Service check functions
check_pipewire() {
    if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
        return 1
    fi
    su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR=/run/user/$DEV_UID; pw-cli info" >/dev/null 2>&1
}

check_wireplumber() {
    if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
        return 1
    fi
    su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR=/run/user/$DEV_UID; wpctl status" >/dev/null 2>&1
}

check_virtual_devices() {
    if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
        return 1
    fi
    su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR=/run/user/$DEV_UID; pw-cli list-objects" 2>/dev/null | grep -q "virtual_speaker\|virtual_microphone"
}

check_xvfb() {
    pgrep -f "Xvfb.*:1" >/dev/null 2>&1
}

check_dbus() {
    pgrep -f "dbus.*system" >/dev/null 2>&1 && [ -S /var/run/dbus/system_bus_socket ]
}

check_kde() {
    pgrep -f "startplasma\|plasmashell" >/dev/null 2>&1
}

check_vnc() {
    pgrep -f "x11vnc.*:1" >/dev/null 2>&1
}

check_novnc() {
    pgrep -f "websockify.*80.*:5901" >/dev/null 2>&1
}

# Service recovery functions
recover_pipewire() {
    log_recovery "🔧 Attempting PipeWire recovery..."
    if [ -f "/usr/local/bin/pipewire-recovery.sh" ]; then
        if timeout $RECOVERY_TIMEOUT /usr/local/bin/pipewire-recovery.sh recover; then
            log_recovery "✅ PipeWire recovery successful"
            return 0
        else
            log_recovery "❌ PipeWire recovery failed or timed out"
            return 1
        fi
    else
        log_recovery "❌ PipeWire recovery script not found"
        return 1
    fi
}

recover_wireplumber() {
    log_recovery "🔧 Attempting WirePlumber recovery..."
    if command -v supervisorctl >/dev/null 2>&1; then
        if timeout $RECOVERY_TIMEOUT supervisorctl restart wireplumber; then
            log_recovery "✅ WirePlumber recovery successful"
            sleep 5
            return 0
        else
            log_recovery "❌ WirePlumber recovery failed or timed out"
            return 1
        fi
    else
        log_recovery "❌ supervisorctl not available"
        return 1
    fi
}

recover_virtual_devices() {
    log_recovery "🔧 Attempting virtual device recovery..."
    if [ -f "/usr/local/bin/create-virtual-pipewire-devices.sh" ]; then
        if timeout $RECOVERY_TIMEOUT /usr/local/bin/create-virtual-pipewire-devices.sh; then
            log_recovery "✅ Virtual device recovery successful"
            return 0
        else
            log_recovery "❌ Virtual device recovery failed or timed out"
            return 1
        fi
    else
        log_recovery "❌ Virtual device creation script not found"
        return 1
    fi
}

recover_service_via_supervisor() {
    local service="$1"
    log_recovery "🔧 Attempting $service recovery via supervisorctl..."
    
    if command -v supervisorctl >/dev/null 2>&1; then
        if timeout $RECOVERY_TIMEOUT supervisorctl restart "$service"; then
            log_recovery "✅ $service recovery successful"
            sleep 5
            return 0
        else
            log_recovery "❌ $service recovery failed or timed out"
            return 1
        fi
    else
        log_recovery "❌ supervisorctl not available"
        return 1
    fi
}

# Main recovery function for a service
recover_service() {
    local service="$1"
    local current_time=$(date +%s)
    
    # Check if in cooldown
    if is_in_cooldown "$service"; then
        local last_recovery=$(get_last_recovery_time "$service")
        local remaining_cooldown=$((DEFAULT_COOLDOWN - (current_time - last_recovery)))
        log_recovery "⏳ $service recovery in cooldown, ${remaining_cooldown}s remaining"
        return 1
    fi
    
    # Check failure count
    local failure_count=$(get_failure_count "$service")
    if [ $failure_count -lt $MAX_FAILURES ]; then
        log_recovery "⚠️  $service failure count ($failure_count) below threshold ($MAX_FAILURES)"
        return 1
    fi
    
    log_recovery "🚨 Attempting recovery for $service (failures: $failure_count)"
    
    # Attempt recovery based on service type
    local recovery_success=false
    case "$service" in
        "pipewire")
            if recover_pipewire; then
                recovery_success=true
            fi
            ;;
        "wireplumber")
            if recover_wireplumber; then
                recovery_success=true
            fi
            ;;
        "virtual-devices")
            if recover_virtual_devices; then
                recovery_success=true
            fi
            ;;
        "xvfb"|"dbus"|"kde"|"vnc"|"novnc")
            if recover_service_via_supervisor "$service"; then
                recovery_success=true
            fi
            ;;
        *)
            log_recovery "❌ Unknown service: $service"
            return 1
            ;;
    esac
    
    # Update state
    set_last_recovery_time "$service" "$current_time"
    
    if [ "$recovery_success" = true ]; then
        set_failure_count "$service" "0"
        log_recovery "✅ Recovery completed successfully for $service"
        return 0
    else
        log_recovery "❌ Recovery failed for $service"
        return 1
    fi
}

# Increment failure count for a service
record_failure() {
    local service="$1"
    local current_count=$(get_failure_count "$service")
    local new_count=$((current_count + 1))
    set_failure_count "$service" "$new_count"
    log_recovery "📊 Recorded failure for $service (count: $new_count)"
}

# Reset failure count for a service
reset_failures() {
    local service="$1"
    set_failure_count "$service" "0"
    log_recovery "✅ Reset failure count for $service"
}

# Comprehensive system health check
system_health_check() {
    log_recovery "🔍 Performing comprehensive system health check..."
    
    local services=(
        "pipewire:check_pipewire"
        "wireplumber:check_wireplumber"
        "virtual-devices:check_virtual_devices"
        "xvfb:check_xvfb"
        "dbus:check_dbus"
        "kde:check_kde"
        "vnc:check_vnc"
        "novnc:check_novnc"
    )
    
    local failed_services=()
    local recovered_services=()
    
    for service_info in "${services[@]}"; do
        local service_name="${service_info%%:*}"
        local check_cmd="${service_info##*:}"
        
        if eval "$check_cmd" >/dev/null 2>&1; then
            # Service is healthy - reset failure count if it was previously failing
            local failure_count=$(get_failure_count "$service_name")
            if [ $failure_count -gt 0 ]; then
                reset_failures "$service_name"
                recovered_services+=("$service_name")
            fi
        else
            # Service is failing - record failure
            record_failure "$service_name"
            failed_services+=("$service_name")
            
            # Attempt recovery if conditions are met
            if recover_service "$service_name"; then
                log_recovery "🎉 Successfully recovered $service_name"
            fi
        fi
    done
    
    # Report results
    if [ ${#failed_services[@]} -eq 0 ]; then
        log_recovery "🎉 All services are healthy"
    else
        log_recovery "⚠️  Failed services: ${failed_services[*]}"
    fi
    
    if [ ${#recovered_services[@]} -gt 0 ]; then
        log_recovery "✅ Recovered services: ${recovered_services[*]}"
    fi
}

# Continuous monitoring mode
continuous_monitor() {
    log_recovery "🚀 Starting continuous service recovery monitoring..."
    
    local monitor_interval=300  # 5 minutes
    local cycle_count=0
    
    while true; do
        cycle_count=$((cycle_count + 1))
        log_recovery "💓 Monitoring cycle $cycle_count"
        
        system_health_check
        
        # Detailed report every 12 cycles (1 hour)
        if [ $((cycle_count % 12)) -eq 0 ]; then
            log_recovery "📊 Hourly detailed status report..."
            show_recovery_status
        fi
        
        sleep $monitor_interval
    done
}

# Show current recovery status
show_recovery_status() {
    log_recovery "=== Service Recovery Status Report ==="
    
    if [ -f "$FAILURE_COUNT_FILE" ]; then
        log_recovery "Current failure counts:"
        while IFS=: read -r service count; do
            if [ "$count" -gt 0 ]; then
                log_recovery "  $service: $count failures"
            fi
        done < "$FAILURE_COUNT_FILE"
    fi
    
    if [ -f "$COOLDOWN_FILE" ]; then
        log_recovery "Services in recovery cooldown:"
        local current_time=$(date +%s)
        while IFS=: read -r service timestamp; do
            local time_since=$((current_time - timestamp))
            if [ $time_since -lt $DEFAULT_COOLDOWN ]; then
                local remaining=$((DEFAULT_COOLDOWN - time_since))
                log_recovery "  $service: ${remaining}s remaining"
            fi
        done < "$COOLDOWN_FILE"
    fi
    
    log_recovery "=== Status Report Complete ==="
}

# Main execution
main() {
    init_state_dir
    
    case "${1:-monitor}" in
        "check")
            system_health_check
            ;;
        "monitor")
            continuous_monitor
            ;;
        "status")
            show_recovery_status
            ;;
        "recover")
            local service="${2:-}"
            if [ -n "$service" ]; then
                recover_service "$service"
            else
                log_recovery "❌ Service name required for recovery"
                exit 1
            fi
            ;;
        "reset")
            local service="${2:-}"
            if [ -n "$service" ]; then
                reset_failures "$service"
            else
                log_recovery "❌ Service name required for reset"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 {check|monitor|status|recover <service>|reset <service>}"
            echo "  check           - Perform one-time health check"
            echo "  monitor         - Start continuous monitoring"
            echo "  status          - Show current recovery status"
            echo "  recover <svc>   - Force recovery attempt for service"
            echo "  reset <svc>     - Reset failure count for service"
            exit 1
            ;;
    esac
}

main "$@"