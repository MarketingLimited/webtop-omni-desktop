#!/bin/bash
# Robust D-Bus startup with health monitoring
set -euo pipefail

LOG_PREFIX="[DBUS-START]"
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') ${LOG_PREFIX} $*"
}

start_dbus() {
    install -o messagebus -g messagebus -m 755 -d /run/dbus
    if ! pgrep -x dbus-daemon >/dev/null 2>&1; then
        log "Starting system D-Bus..."
        dbus-daemon --system --fork --print-pid > /run/dbus/pid 2>/dev/null || true
    else
        log "System D-Bus already running"
    fi
}

check_dbus() {
    dbus-send --system --dest=org.freedesktop.DBus --type=method_call --print-reply \
        /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1
}

wait_for_dbus() {
    local timeout="${DBUS_TIMEOUT:-30}"
    local elapsed=0
    log "Waiting for D-Bus to become ready (timeout ${timeout}s)"
    until check_dbus; do
        if [ "$elapsed" -ge "$timeout" ]; then
            log "D-Bus failed to become ready"
            return 1
        fi
        sleep 1
        elapsed=$((elapsed + 1))
        if (( elapsed % 5 == 0 )); then
            log "Still waiting for D-Bus... (${elapsed}s)"
        fi
    done
    log "D-Bus is ready"
}

monitor_dbus() {
    local interval="${DBUS_MONITOR_INTERVAL:-5}"
    while true; do
        sleep "$interval"
        if ! check_dbus; then
            log "D-Bus unhealthy, restarting..."
            start_dbus
            wait_for_dbus || log "Restart attempt failed"
        fi
    done
}

start_dbus
wait_for_dbus
monitor_dbus &

if [ "$#" -gt 0 ]; then
    exec "$@"
else
    log "No command provided. D-Bus monitor running."
    tail -f /dev/null
fi
