#!/bin/bash
# D-Bus Readiness Check Script
# Ensures D-Bus is available before starting dependent services

set -euo pipefail

TIMEOUT="${DBUS_TIMEOUT:-30}"
CHECK_INTERVAL="${DBUS_CHECK_INTERVAL:-1}"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DBUS-WAIT] $1"
}

wait_for_dbus() {
    local counter=0
    
    log_message "Waiting for D-Bus system service (timeout: ${TIMEOUT}s)"
    
    while [ $counter -lt $TIMEOUT ]; do
        # Check if D-Bus socket exists
        if [ -S /run/dbus/system_bus_socket ]; then
            # Verify D-Bus is responsive
            if dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetId >/dev/null 2>&1; then
                log_message "D-Bus system service is ready"
                return 0
            fi
        fi
        
        sleep $CHECK_INTERVAL
        counter=$((counter + CHECK_INTERVAL))
        
        if [ $((counter % 10)) -eq 0 ]; then
            log_message "Still waiting for D-Bus... (${counter}s elapsed)"
        fi
    done
    
    log_message "Timeout waiting for D-Bus system service" >&2
    return 1
}

# Main execution
# Allow passing through optional arguments such as a custom timeout.
wait_for_dbus "$@"
