#!/bin/bash
# Advanced Service Management Script for Ubuntu KDE Docker
# Provides intelligent service control and health management

set -euo pipefail

LOG_FILE="/var/log/service-manager.log"
METRICS_FILE="/tmp/service-metrics.txt"
RECOVERY_STATE_FILE="/tmp/service-recovery-state.txt"

# Service groups configuration
declare -A SERVICE_GROUPS=(
    [core]="dbus"
    [audio]="pulseaudio AudioValidation CreateVirtualAudioDevices AudioMonitor AudioBridge"
    [remote]="KasmVNC sshd ttyd"
    [monitoring]="ServiceHealth SystemValidation"
    [setup]="SetupDesktop"
)

declare -A SERVICE_PRIORITIES=(
    [core]=10
    [audio]=25
    [remote]=40
    [setup]=50
    [monitoring]=55
)

# Logging function with levels
log_manager() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] [SERVICE-MANAGER] $message" | tee -a "$LOG_FILE"
}

# Get service status with detailed information
get_service_status() {
    local service="$1"
    local status_line=$(supervisorctl status "$service" 2>/dev/null || echo "NOT_FOUND")
    
    if [[ "$status_line" == "NOT_FOUND" ]]; then
        echo "NOT_FOUND"
    elif [[ "$status_line" == *"RUNNING"* ]]; then
        echo "RUNNING"
    elif [[ "$status_line" == *"STOPPED"* ]]; then
        echo "STOPPED"
    elif [[ "$status_line" == *"FATAL"* ]]; then
        echo "FATAL"
    elif [[ "$status_line" == *"BACKOFF"* ]]; then
        echo "BACKOFF"
    else
        echo "UNKNOWN"
    fi
}

# Start service group with dependency management
start_service_group() {
    local group="$1"
    log_manager "INFO" "Starting service group: $group"
    
    if [[ -z "${SERVICE_GROUPS[$group]:-}" ]]; then
        log_manager "ERROR" "Unknown service group: $group"
        return 1
    fi
    
    local services="${SERVICE_GROUPS[$group]}"
    local failed_services=()
    
    for service in $services; do
        local status=$(get_service_status "$service")
        
        if [[ "$status" != "RUNNING" ]]; then
            log_manager "INFO" "Starting service: $service (current status: $status)"
            
            if supervisorctl start "$service" >/dev/null 2>&1; then
                # Wait for service to stabilize
                sleep 2
                local new_status=$(get_service_status "$service")
                
                if [[ "$new_status" == "RUNNING" ]]; then
                    log_manager "INFO" "Successfully started: $service"
                else
                    log_manager "WARN" "Service $service started but not running (status: $new_status)"
                    failed_services+=("$service")
                fi
            else
                log_manager "ERROR" "Failed to start service: $service"
                failed_services+=("$service")
            fi
        else
            log_manager "INFO" "Service already running: $service"
        fi
    done
    
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        log_manager "INFO" "Service group $group started successfully"
        return 0
    else
        log_manager "WARN" "Service group $group started with failures: ${failed_services[*]}"
        return 1
    fi
}

# Stop service group gracefully
stop_service_group() {
    local group="$1"
    log_manager "INFO" "Stopping service group: $group"
    
    if [[ -z "${SERVICE_GROUPS[$group]:-}" ]]; then
        log_manager "ERROR" "Unknown service group: $group"
        return 1
    fi
    
    local services="${SERVICE_GROUPS[$group]}"
    
    # Stop services in reverse order
    local reversed_services=$(echo $services | tr ' ' '\n' | tac | tr '\n' ' ')
    
    for service in $reversed_services; do
        local status=$(get_service_status "$service")
        
        if [[ "$status" == "RUNNING" ]]; then
            log_manager "INFO" "Stopping service: $service"
            supervisorctl stop "$service" >/dev/null 2>&1 || true
        fi
    done
    
    log_manager "INFO" "Service group $group stopped"
}

# Restart service group with intelligent recovery
restart_service_group() {
    local group="$1"
    local recovery_delay="${2:-5}"
    
    log_manager "INFO" "Restarting service group: $group with ${recovery_delay}s delay"
    
    stop_service_group "$group"
    sleep "$recovery_delay"
    start_service_group "$group"
}

# Get system health score (0-100)
get_health_score() {
    local total_services=0
    local running_services=0
    local critical_services=0
    local critical_running=0
    
    for group in "${!SERVICE_GROUPS[@]}"; do
        local services="${SERVICE_GROUPS[$group]}"
        
        for service in $services; do
            total_services=$((total_services + 1))
            local status=$(get_service_status "$service")
            
            if [[ "$status" == "RUNNING" ]]; then
                running_services=$((running_services + 1))
            fi
            
            # Core and remote services are critical
            if [[ "$group" == "core" ]] || [[ "$group" == "remote" ]]; then
                critical_services=$((critical_services + 1))
                if [[ "$status" == "RUNNING" ]]; then
                    critical_running=$((critical_running + 1))
                fi
            fi
        done
    done
    
    # Health score: 70% weight for all services, 30% weight for critical services
    local overall_score=0
    if [[ $total_services -gt 0 ]]; then
        overall_score=$((running_services * 70 / total_services))
    fi
    
    local critical_score=0
    if [[ $critical_services -gt 0 ]]; then
        critical_score=$((critical_running * 30 / critical_services))
    fi
    
    echo $((overall_score + critical_score))
}

# Generate comprehensive status report
generate_status_report() {
    local health_score=$(get_health_score)
    
    log_manager "INFO" "=== SYSTEM STATUS REPORT ==="
    log_manager "INFO" "Health Score: $health_score/100"
    
    for group in core audio desktop remote monitoring setup; do
        if [[ -n "${SERVICE_GROUPS[$group]:-}" ]]; then
            local services="${SERVICE_GROUPS[$group]}"
            local group_status="HEALTHY"
            local running_count=0
            local total_count=0
            
            log_manager "INFO" "--- $group Group ---"
            
            for service in $services; do
                total_count=$((total_count + 1))
                local status=$(get_service_status "$service")
                
                if [[ "$status" == "RUNNING" ]]; then
                    running_count=$((running_count + 1))
                    log_manager "INFO" "  ✅ $service: $status"
                else
                    group_status="DEGRADED"
                    log_manager "WARN" "  ❌ $service: $status"
                fi
            done
            
            log_manager "INFO" "  Group Status: $group_status ($running_count/$total_count running)"
        fi
    done
    
    # Update metrics file
    cat > "$METRICS_FILE" << EOF
timestamp=$(date +%s)
health_score=$health_score
total_services=$(supervisorctl status | wc -l)
running_services=$(supervisorctl status | grep -c "RUNNING" || echo 0)
failed_services=$(supervisorctl status | grep -cE "(FATAL|BACKOFF)" || echo 0)
EOF
}

# Auto-recovery for failed services
auto_recovery() {
    log_manager "INFO" "Starting auto-recovery process..."
    
    local recovery_attempts=0
    local max_attempts=3
    
    # Check for recovery state
    if [[ -f "$RECOVERY_STATE_FILE" ]]; then
        recovery_attempts=$(cat "$RECOVERY_STATE_FILE" 2>/dev/null || echo 0)
    fi
    
    if [[ $recovery_attempts -ge $max_attempts ]]; then
        log_manager "WARN" "Maximum recovery attempts reached ($max_attempts), skipping auto-recovery"
        return 1
    fi
    
    recovery_attempts=$((recovery_attempts + 1))
    echo "$recovery_attempts" > "$RECOVERY_STATE_FILE"
    
    log_manager "INFO" "Auto-recovery attempt $recovery_attempts/$max_attempts"
    
    # Identify failed service groups and restart them
    local groups_restarted=false
    
    for group in core audio desktop remote; do
        local services="${SERVICE_GROUPS[$group]}"
        local has_failed=false
        
        for service in $services; do
            local status=$(get_service_status "$service")
            if [[ "$status" == "FATAL" ]] || [[ "$status" == "BACKOFF" ]]; then
                has_failed=true
                break
            fi
        done
        
        if [[ "$has_failed" == "true" ]]; then
            log_manager "INFO" "Attempting recovery for group: $group"
            restart_service_group "$group" $((recovery_attempts * 5))
            groups_restarted=true
        fi
    done
    
    if [[ "$groups_restarted" == "false" ]]; then
        log_manager "INFO" "No failed service groups found, resetting recovery state"
        rm -f "$RECOVERY_STATE_FILE"
    fi
}

# Main command dispatcher
main() {
    case "${1:-status}" in
        "start")
            if [[ -n "${2:-}" ]]; then
                start_service_group "$2"
            else
                # Start all groups in priority order
                for group in core audio desktop remote setup monitoring; do
                    start_service_group "$group"
                    sleep 2
                done
            fi
            ;;
        "stop")
            if [[ -n "${2:-}" ]]; then
                stop_service_group "$2"
            else
                # Stop all groups in reverse priority order
                for group in monitoring setup remote desktop audio core; do
                    stop_service_group "$group"
                    sleep 1
                done
            fi
            ;;
        "restart")
            if [[ -n "${2:-}" ]]; then
                restart_service_group "$2" "${3:-5}"
            else
                log_manager "INFO" "Restarting all service groups"
                main stop
                sleep 5
                main start
            fi
            ;;
        "status"|"health")
            generate_status_report
            ;;
        "recover")
            auto_recovery
            ;;
        "reset")
            log_manager "INFO" "Resetting all services and recovery state"
            rm -f "$RECOVERY_STATE_FILE"
            main restart
            ;;
        *)
            echo "Usage: $0 {start|stop|restart|status|recover|reset} [group] [delay]"
            echo ""
            echo "Commands:"
            echo "  start [group]    - Start all services or specific group"
            echo "  stop [group]     - Stop all services or specific group"
            echo "  restart [group]  - Restart all services or specific group"
            echo "  status           - Generate detailed status report"
            echo "  recover          - Attempt auto-recovery of failed services"
            echo "  reset            - Reset all services and recovery state"
            echo ""
            echo "Service Groups: ${!SERVICE_GROUPS[*]}"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"