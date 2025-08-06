#!/bin/bash
# PipeWire Recovery Script
# Handles PipeWire service failures and attempts recovery using supervisord.

set -euo pipefail

LOG_FILE="/var/log/supervisor/pipewire-recovery.log"

# Color output functions
red() { echo -e "\033[31m$*\033[0m" | tee -a "$LOG_FILE"; }
green() { echo -e "\033[32m$*\033[0m" | tee -a "$LOG_FILE"; }
yellow() { echo -e "\033[33m$*\033[0m" | tee -a "$LOG_FILE"; }
blue() { echo -e "\033[34m$*\033[0m" | tee -a "$LOG_FILE"; }

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# Health check for audio services
health_check() {
    log "Performing health check for audio services..."
    local services_ok=true

    # Check PipeWire
    if ! supervisorctl status pipewire | grep -q "RUNNING"; then
        red "PipeWire is not running."
        services_ok=false
    else
        green "PipeWire is running."
    fi

    # Check WirePlumber
    if ! supervisorctl status wireplumber | grep -q "RUNNING"; then
        red "WirePlumber is not running."
        services_ok=false
    else
        green "WirePlumber is running."
    fi

    if [ "$services_ok" = true ]; then
        log "All audio services are healthy."
        return 0
    else
        log "One or more audio services are unhealthy."
        return 1
    fi
}

# Restart audio services via supervisord
restart_services() {
    log "Restarting audio services via supervisord..."
    
    # Stop all services in the audio group
    if supervisorctl stop audio:*; then
        log "Stopped all audio services."
        sleep 5 # Give time for services to stop
    else
        red "Failed to stop audio services. Attempting to continue..."
    fi
    
    # Start all services in the audio group
    if supervisorctl start audio:*; then
        log "Started all audio services."
        sleep 10 # Give time for services to initialize
    else
        red "Failed to start audio services."
        return 1
    fi

    # Final health check
    if health_check; then
        green "Audio services restarted successfully."
        return 0
    else
        red "Audio services failed to restart correctly."
        return 1
    fi
}

# Main execution
main() {
    log "--- PipeWire Recovery Script Started ---"
    
    if ! command -v supervisorctl >/dev/null 2>&1; then
        red "supervisorctl command not found. Cannot proceed."
        exit 1
    fi

    case "${1:-"health_check"}" in
        "health_check")
            health_check
            ;;
        "recover")
            if ! health_check; then
                log "Health check failed. Attempting recovery..."
                restart_services
            else
                log "Services are healthy. No recovery needed."
            fi
            ;;
        *)
            red "Invalid command: $1"
            echo "Usage: $0 {health_check|recover}"
            exit 1
            ;;
    esac

    log "--- PipeWire Recovery Script Finished ---"
}

main "$@"