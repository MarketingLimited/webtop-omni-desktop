#!/bin/bash
# Enhanced service monitoring script with health checks for critical services

set -euo pipefail

LOG_FILE="/var/log/service-monitor.log"
MONITOR_INTERVAL="${MONITOR_INTERVAL:-120}"
MAX_RETRIES=3

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log_message() {
    local message="$1"
    local level="${2:-INFO}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] [MONITOR] $message" | tee -a "$LOG_FILE"
}

check_dbus() {
    if pgrep -x dbus-daemon >/dev/null; then
        return 0
    fi

    log_message "D-Bus daemon not running, attempting restart..." "WARN"
    if dbus-daemon --system --fork; then
        log_message "D-Bus daemon restarted successfully" "INFO"
        return 0
    fi

    log_message "Failed to restart D-Bus" "ERROR"
    return 1
}

check_polkit() {
    if pgrep -x polkitd >/dev/null; then
        return 0
    fi

    if [ -S /run/dbus/system_bus_socket ]; then
        log_message "PolicyKit daemon not running, attempting restart..." "WARN"
        /usr/lib/polkit-1/polkitd --no-debug >/dev/null 2>&1 &
        sleep 1
        if pgrep -x polkitd >/dev/null; then
            log_message "PolicyKit daemon restarted" "INFO"
            return 0
        fi
    fi

    log_message "Failed to restart PolicyKit" "ERROR"
    return 1
}

check_vnc() {
    if nc -z localhost 5901 2>/dev/null; then
        return 0
    fi

    log_message "VNC server not responding on port 5901" "WARN"
    return 1
}

check_service() {
    case "$1" in
        dbus)   check_dbus ;;
        polkit) check_polkit ;;
        vnc)    check_vnc ;;
        *)      return 0 ;;
    esac
}

SERVICES=(dbus polkit vnc)

log_message "Service monitor started with ${MONITOR_INTERVAL}s interval" "INFO"

consecutive_failures=0

while true; do
    sleep "$MONITOR_INTERVAL"

    cycle_failed=0
    for service in "${SERVICES[@]}"; do
        if ! check_service "$service"; then
            cycle_failed=1
        fi
    done

    if [ "$cycle_failed" -eq 1 ]; then
        consecutive_failures=$((consecutive_failures + 1))
    else
        consecutive_failures=0
    fi

    if [ "$consecutive_failures" -ge "$MAX_RETRIES" ]; then
        log_message "Too many failures, increasing monitoring interval" "WARN"
        MONITOR_INTERVAL=$((MONITOR_INTERVAL * 2))
        if [ "$MONITOR_INTERVAL" -gt 600 ]; then
            MONITOR_INTERVAL=600
        fi
        consecutive_failures=0
    elif [ "$consecutive_failures" -eq 0 ] && [ "$MONITOR_INTERVAL" -gt 120 ]; then
        MONITOR_INTERVAL=$((MONITOR_INTERVAL / 2))
        if [ "$MONITOR_INTERVAL" -lt 120 ]; then
            MONITOR_INTERVAL=120
        fi
    fi
done

