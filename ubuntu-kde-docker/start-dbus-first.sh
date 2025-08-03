#!/bin/bash
set -euo pipefail

echo "INFO: Enhanced D-Bus starter script initiated."

# Enhanced logging and error handling
LOG_FILE="/var/log/supervisor/dbus-startup.log"
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    local message="$1"
    local level="${2:-INFO}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] [DBUS] $message" | tee -a "$LOG_FILE"
}

cleanup_and_exit() {
    local exit_code=$1
    log_message "D-Bus startup failed with exit code $exit_code" "ERROR"
    if [ -n "${DBUS_PID:-}" ] && kill -0 "$DBUS_PID" 2>/dev/null; then
        kill "$DBUS_PID" 2>/dev/null || true
    fi
    exit "$exit_code"
}

trap 'cleanup_and_exit $?' ERR

# Ensure basic runtime environment variables are set
export HOME="${HOME:-/root}"
export DEV_USERNAME="${DEV_USERNAME:-devuser}"
export DEV_UID="${DEV_UID:-1000}"
export DEV_GID="${DEV_GID:-1000}"

log_message "Starting with user: $DEV_USERNAME (UID: $DEV_UID)"

# Enhanced runtime directory setup with better error handling
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${DEV_UID}}"
if [ ! -d "$RUNTIME_DIR" ]; then
    mkdir -p "$RUNTIME_DIR" || {
        log_message "Failed to create runtime directory: $RUNTIME_DIR" "ERROR"
        exit 1
    }
    
    # Only change ownership if user exists
    if id "$DEV_USERNAME" >/dev/null 2>&1; then
        chown "${DEV_UID}:${DEV_GID}" "$RUNTIME_DIR" 2>/dev/null || true
        chmod 700 "$RUNTIME_DIR" 2>/dev/null || true
        log_message "Runtime directory configured for $DEV_USERNAME"
    else
        log_message "User $DEV_USERNAME doesn't exist yet, skipping ownership changes" "WARN"
    fi
fi
export XDG_RUNTIME_DIR="$RUNTIME_DIR"

# Enhanced D-Bus directory and dependencies setup
log_message "Setting up D-Bus directories and dependencies"

# Ensure messagebus user exists before setting permissions
if ! id messagebus >/dev/null 2>&1; then
    log_message "Creating messagebus user" "WARN"
    useradd -r -s /bin/false -d /run/dbus messagebus 2>/dev/null || true
fi

# Create D-Bus runtime directory with proper permissions
if ! install -o messagebus -g messagebus -m 755 -d /run/dbus 2>/dev/null; then
    mkdir -p /run/dbus || {
        log_message "Failed to create /run/dbus directory" "ERROR"
        exit 1
    }
    chown messagebus:messagebus /run/dbus 2>/dev/null || {
        log_message "Failed to set ownership on /run/dbus" "WARN"
    }
    chmod 755 /run/dbus
fi

# Ensure machine-id exists and is valid
if [ ! -s /etc/machine-id ]; then
    log_message "Creating machine-id"
    dbus-uuidgen --ensure=/etc/machine-id || {
        log_message "Failed to create machine-id" "ERROR"
        exit 1
    }
fi

# Verify machine-id is valid
if [ ! -s /etc/machine-id ] || [ "$(wc -c < /etc/machine-id)" -lt 32 ]; then
    log_message "Invalid machine-id detected, regenerating" "WARN"
    rm -f /etc/machine-id /var/lib/dbus/machine-id
    dbus-uuidgen --ensure=/etc/machine-id || exit 1
    ln -sf /etc/machine-id /var/lib/dbus/machine-id 2>/dev/null || true
fi

# Enhanced D-Bus startup with robust error handling
if pgrep -x dbus-daemon >/dev/null; then
    log_message "D-Bus daemon already running, verifying health"
    if [ -f /run/dbus/pid ]; then
        DBUS_PID=$(cat /run/dbus/pid)
        if ! kill -0 "$DBUS_PID" 2>/dev/null; then
            log_message "Stale PID file detected, cleaning up" "WARN"
            rm -f /run/dbus/pid
            DBUS_PID=$(pgrep -x dbus-daemon | head -n 1)
            echo "$DBUS_PID" > /run/dbus/pid
        fi
    else
        DBUS_PID=$(pgrep -x dbus-daemon | head -n 1)
        echo "$DBUS_PID" > /run/dbus/pid
    fi
    
    # Verify existing D-Bus is responsive
    if ! dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetId >/dev/null 2>&1; then
        log_message "Existing D-Bus not responsive, restarting" "WARN"
        kill "$DBUS_PID" 2>/dev/null || true
        sleep 2
        rm -f /run/dbus/system_bus_socket /run/dbus/pid
        unset DBUS_PID
    fi
fi

if [ -z "${DBUS_PID:-}" ]; then
    log_message "Starting new D-Bus daemon"
    
    # Clean up any stale files
    rm -f /run/dbus/system_bus_socket /run/dbus/pid
    
    # Enhanced D-Bus startup with better error detection
    if ! /usr/bin/dbus-daemon --system --nofork --nosyslog --print-pid=/run/dbus/pid.tmp 2>&1 &
    then
        log_message "Failed to start D-Bus daemon" "ERROR"
        exit 1
    fi
    
    DBUS_PID=$!
    
    # Wait briefly for PID file creation
    counter=0
    while [ ! -f /run/dbus/pid.tmp ] && [ $counter -lt 10 ]; do
        sleep 0.1
        counter=$((counter+1))
    done
    
    if [ -f /run/dbus/pid.tmp ]; then
        mv /run/dbus/pid.tmp /run/dbus/pid
    else
        echo "$DBUS_PID" > /run/dbus/pid
    fi
    
    log_message "Waiting for D-Bus socket creation..."
    counter=0
    while [ ! -S /run/dbus/system_bus_socket ] && [ $counter -lt 30 ]; do
        if ! kill -0 "$DBUS_PID" 2>/dev/null; then
            log_message "D-Bus daemon died during startup" "ERROR"
            exit 1
        fi
        sleep 0.5
        counter=$((counter+1))
    done
    
    if [ ! -S /run/dbus/system_bus_socket ]; then
        log_message "D-Bus socket creation timeout" "ERROR"
        kill "$DBUS_PID" 2>/dev/null || true
        exit 1
    fi
    
    log_message "D-Bus socket created, verifying responsiveness..."
    counter=0
    while ! dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetId >/dev/null 2>&1 && [ $counter -lt 30 ]; do
        if ! kill -0 "$DBUS_PID" 2>/dev/null; then
            log_message "D-Bus daemon died during verification" "ERROR"
            exit 1
        fi
        sleep 0.5
        counter=$((counter+1))
    done
    
    if ! dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetId >/dev/null 2>&1; then
        log_message "D-Bus service not responsive after startup" "ERROR"
        kill "$DBUS_PID" 2>/dev/null || true
        exit 1
    fi
    
    log_message "D-Bus service is responsive and ready"
fi

# Enhanced cleanup trap
trap 'log_message "Shutting down D-Bus daemon"; kill "$DBUS_PID" 2>/dev/null || true; sleep 1' EXIT TERM INT

# Enhanced dependent services startup with better error handling
log_message "Starting dependent services"

# Start accounts-daemon with retry logic
start_accounts_daemon() {
    if ! pgrep -x accounts-daemon >/dev/null; then
        local daemon_path=""
        if [ -x /usr/libexec/accounts-daemon ]; then
            daemon_path="/usr/libexec/accounts-daemon"
        elif [ -x /usr/lib/accountsservice/accounts-daemon ]; then
            daemon_path="/usr/lib/accountsservice/accounts-daemon"
        fi
        
        if [ -n "$daemon_path" ]; then
            log_message "Starting accounts-daemon: $daemon_path"
            "$daemon_path" &
            
            # Verify it started successfully
            sleep 2
            if pgrep -x accounts-daemon >/dev/null; then
                log_message "accounts-daemon started successfully"
            else
                log_message "accounts-daemon failed to start" "WARN"
            fi
        else
            log_message "accounts-daemon not found (non-critical)" "WARN"
        fi
    else
        log_message "accounts-daemon already running"
    fi
}

# Start polkitd with better error handling
start_polkitd() {
    if ! pgrep -x polkitd >/dev/null; then
        if [ -x /usr/lib/polkit-1/polkitd ]; then
            log_message "Starting polkitd"
            /usr/lib/polkit-1/polkitd --no-debug &
            
            # Verify it started successfully
            sleep 2
            if pgrep -x polkitd >/dev/null; then
                log_message "polkitd started successfully"
            else
                log_message "polkitd failed to start" "WARN"
            fi
        else
            log_message "polkitd not found (non-critical)" "WARN"
        fi
    else
        log_message "polkitd already running"
    fi
}

# Start dependent services
start_accounts_daemon
start_polkitd

log_message "D-Bus and dependent services startup complete"

# Enhanced monitoring loop with periodic health checks
monitor_dbus() {
    local failure_count=0
    local max_failures=3
    
    while true; do
        if ! kill -0 "$DBUS_PID" 2>/dev/null; then
            log_message "D-Bus daemon process died" "ERROR"
            exit 1
        fi
        
        # Periodic health check
        if ! dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetId >/dev/null 2>&1; then
            failure_count=$((failure_count + 1))
            log_message "D-Bus health check failed ($failure_count/$max_failures)" "WARN"
            
            if [ $failure_count -ge $max_failures ]; then
                log_message "D-Bus health check failed too many times" "ERROR"
                exit 1
            fi
        else
            failure_count=0
        fi
        
        sleep 5
    done
}

# Wait for the main dbus-daemon process with health monitoring
monitor_dbus
