#!/bin/bash
# Enhanced service monitoring script with health checks

DEV_USERNAME="${DEV_USERNAME:-devuser}"
LOG_FILE="/var/log/service-monitor.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [MONITOR] $1" | tee -a "$LOG_FILE"
}

check_dbus() {
    if ! pgrep -x dbus-daemon >/dev/null; then
        log_message "D-Bus daemon not running, attempting restart..."
        dbus-daemon --system --fork || log_message "Failed to restart D-Bus"
    fi
}

check_polkit() {
    if ! pgrep -x polkitd >/dev/null; then
        log_message "PolicyKit daemon not running"
        if [ -S /run/dbus/system_bus_socket ]; then
            log_message "Attempting to restart polkitd..."
            /usr/lib/polkit-1/polkitd --no-debug &
        fi
    fi
}

check_vnc() {
    if ! nc -z localhost 5901 2>/dev/null; then
        log_message "VNC server not responding on port 5901"
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

log_message "Service monitor started"

# Main monitoring loop
while true; do
    sleep 30
    check_services "dbus"
    check_services "polkit" 
    check_services "vnc"
done