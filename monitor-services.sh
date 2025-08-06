#!/bin/bash
# Enhanced service monitoring script with health checks

DEV_USERNAME="${DEV_USERNAME:-devuser}"
LOG_FILE="/var/log/service-monitor.log"
MONITOR_INTERVAL="${MONITOR_INTERVAL:-120}"
RETRY_COUNT=0
MAX_RETRIES=3

log_message() {
    local level="${2:-INFO}"
    if [ "$level" = "ERROR" ] || [ "$level" = "WARN" ] || [ "$RETRY_COUNT" -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] [MONITOR] $1" | tee -a "$LOG_FILE"
    fi
}

check_dbus() {
    if ! pgrep -x dbus-daemon >/dev/null; then
        log_message "D-Bus daemon not running, attempting restart..." "WARN"
        if dbus-daemon --system --fork; then
            log_message "D-Bus daemon restarted successfully" "INFO"
            RETRY_COUNT=0
        else
            log_message "Failed to restart D-Bus" "ERROR"
            RETRY_COUNT=$((RETRY_COUNT + 1))
        fi
    fi
}

check_polkit() {
    if ! pgrep -x polkitd >/dev/null; then
        if [ -S /run/dbus/system_bus_socket ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            log_message "PolicyKit daemon not running, attempting restart..." "WARN"
            if /usr/lib/polkit-1/polkitd --no-debug & then
                log_message "PolicyKit daemon restarted" "INFO"
                RETRY_COUNT=0
            else
                RETRY_COUNT=$((RETRY_COUNT + 1))
            fi
        fi
    fi
}

check_vnc() {
    if ! nc -z localhost 5901 2>/dev/null; then
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            log_message "VNC server not responding on port 5901" "WARN"
            RETRY_COUNT=$((RETRY_COUNT + 1))
        fi
    else
        RETRY_COUNT=0
    fi
}

check_services() {
    local service="$1"
    case "$service" in
        "dbus") check_dbus ;;
        "polkit") check_polkit ;;
        "vnc") check_vnc ;;
    esac
}

log_message "Service monitor started with ${MONITOR_INTERVAL}s interval" "INFO"

# Main monitoring loop with intelligent backoff
while true; do
    sleep "$MONITOR_INTERVAL"
    
    check_services "dbus"
    check_services "polkit" 
    check_services "vnc"
    
    # Adaptive monitoring - increase interval if too many retries
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        log_message "Too many failures, increasing monitoring interval" "WARN"
        MONITOR_INTERVAL=$((MONITOR_INTERVAL * 2))
        if [ $MONITOR_INTERVAL -gt 600 ]; then
            MONITOR_INTERVAL=600  # Cap at 10 minutes
        fi
        RETRY_COUNT=0
    elif [ $RETRY_COUNT -eq 0 ] && [ $MONITOR_INTERVAL -gt 120 ]; then
        # Reduce interval if services are stable
        MONITOR_INTERVAL=$((MONITOR_INTERVAL / 2))
        if [ $MONITOR_INTERVAL -lt 120 ]; then
            MONITOR_INTERVAL=120  # Minimum 2 minutes
        fi
    fi
done