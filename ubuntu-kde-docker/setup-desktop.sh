#!/bin/bash
# Enhanced Desktop Setup Script
# Handles KDE Plasma desktop environment setup for container

set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"
DEV_GID="${DEV_GID:-1000}"

LOG_FILE="/var/log/supervisor/setup-desktop.log"
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    local message="$1"
    local level="${2:-INFO}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] [DESKTOP] $message" | tee -a "$LOG_FILE"
}

# Graceful exit for non-critical failures
graceful_exit() {
    local exit_code="${1:-0}"
    local message="${2:-Desktop setup completed}"
    log_message "$message"
    exit "$exit_code"
}

log_message "Starting desktop environment setup"

# Check if we're in headless mode
if [ "${HEADLESS_MODE:-false}" = "true" ]; then
    graceful_exit 0 "Headless mode detected, skipping desktop setup"
fi

# Verify D-Bus is available before proceeding
if [ ! -S /run/dbus/system_bus_socket ]; then
    log_message "D-Bus not available, waiting..." "WARN"
    counter=0
    while [ ! -S /run/dbus/system_bus_socket ] && [ $counter -lt 30 ]; do
        sleep 1
        counter=$((counter+1))
    done
    
    if [ ! -S /run/dbus/system_bus_socket ]; then
        graceful_exit 0 "D-Bus not available, skipping desktop setup"
    fi
fi

# Check if user exists
if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
    log_message "User $DEV_USERNAME doesn't exist yet, skipping desktop setup" "WARN"
    graceful_exit 0 "User not ready"
fi

log_message "Setting up desktop environment for user: $DEV_USERNAME"

# Ensure XDG directories exist
XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
mkdir -p "$XDG_RUNTIME_DIR" || true
chown "${DEV_UID}:${DEV_GID}" "$XDG_RUNTIME_DIR" 2>/dev/null || true
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true

# Setup KDE configuration directories
setup_kde_directories() {
    local home_dir="/home/${DEV_USERNAME}"
    
    # Create essential KDE directories
    local kde_dirs=(
        ".config"
        ".local/share"
        ".cache"
        ".config/kde.org"
        ".config/plasma-org.kde.plasma.desktop-appletsrc"
        ".local/share/kactivitymanagerd"
    )
    
    for dir in "${kde_dirs[@]}"; do
        mkdir -p "${home_dir}/${dir}" || true
        chown "${DEV_UID}:${DEV_GID}" "${home_dir}/${dir}" 2>/dev/null || true
    done
    
    log_message "KDE directories configured"
}

# Configure KDE for container environment
configure_kde_for_container() {
    local home_dir="/home/${DEV_USERNAME}"
    local config_dir="${home_dir}/.config"
    
    # Create basic KDE configuration
    cat > "${config_dir}/kdeglobals" <<EOF
[General]
BrowserApplication=firefox
TerminalApplication=konsole

[KDE]
SingleClick=false

[WM]
activeBackground=49,54,59
activeBlend=255,255,255
activeForeground=252,252,252
inactiveBackground=42,46,50
inactiveBlend=75,71,67
inactiveForeground=161,169,177
EOF

    # Disable unnecessary KDE services for container
    cat > "${config_dir}/kdeconnectrc" <<EOF
[General]
autostart=false
EOF

    # Configure Plasma for container environment
    cat > "${config_dir}/plasmarc" <<EOF
[General]
immutability=1

[PlasmaViews][Panel 1]
alignment=132
floating=0
maxLength=1920
minLength=1920
offset=0
EOF

    chown -R "${DEV_UID}:${DEV_GID}" "$config_dir" 2>/dev/null || true
    log_message "KDE configured for container environment"
}

# Setup desktop integration scripts
setup_desktop_integration() {
    # Create desktop session wrapper
    cat > /usr/local/bin/start-desktop-session <<'EOF'
#!/bin/bash
export DISPLAY=${DISPLAY:-:1}
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=KDE

# Ensure D-Bus session
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    eval "$(dbus-launch --sh-syntax --exit-with-session)"
fi

# Start KDE Plasma
exec startplasma-x11
EOF

    chmod +x /usr/local/bin/start-desktop-session
    log_message "Desktop integration scripts created"
}

# Main setup execution
main() {
    setup_kde_directories
    configure_kde_for_container
    setup_desktop_integration
    
    # Test KDE components availability
    if command -v startplasma-x11 >/dev/null 2>&1; then
        log_message "KDE Plasma available and configured"
    else
        log_message "KDE Plasma not found, desktop may not function properly" "WARN"
    fi
    
    graceful_exit 0 "Desktop setup completed successfully"
}

main "$@"