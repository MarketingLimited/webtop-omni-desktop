#!/bin/bash
# PipeWire Startup and Configuration Script
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

# Function to wait for the PipeWire socket
wait_for_pipewire_socket() {
    blue "🔄 Waiting for PipeWire socket..."
    local retries=30
    while [ $retries -gt 0 ] && [ ! -S "/run/user/${DEV_UID}/pipewire-0" ]; do
        sleep 1
        retries=$((retries - 1))
    done

    if [ ! -S "/run/user/${DEV_UID}/pipewire-0" ]; then
        red "❌ PipeWire socket not found after 30 seconds."
        return 1
    fi
    green "✅ PipeWire socket is available."
}

# Main function
main() {
    blue "🔧 Initializing PipeWire startup sequence..."

    if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
        yellow "⚠️  User '$DEV_USERNAME' does not exist. Using 'root' instead."
        DEV_USERNAME="root"
        DEV_UID=0
    fi
    export DEV_USERNAME DEV_UID

    # 1. Ensure runtime directories exist
    mkdir -p "/run/user/${DEV_UID}/pipewire"
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}"
    chmod 700 "/run/user/${DEV_UID}"

    # 2. Set permissions for audio devices
    if [ -d "/dev/snd" ]; then
        chown -R root:audio /dev/snd
        chmod -R g+rw /dev/snd
        if [ "$DEV_USERNAME" != "root" ]; then
            usermod -a -G audio "${DEV_USERNAME}" 2>/dev/null || true
        fi
    fi

    # 3. Ensure a D-Bus session is available before starting services
    if ! pgrep -x dbus-daemon >/dev/null 2>&1; then
        yellow "⚠️ D-Bus session not running. Skipping PipeWire startup."
        return 0
    fi

    # 4. Start PipeWire and WirePlumber services
    blue "🚀 Starting PipeWire and WirePlumber services..."
    if ! supervisord -c /etc/supervisor/conf.d/pipewire.conf; then
        yellow "⚠️ Unable to start PipeWire via supervisord. Continuing without audio services."
        return 0
    fi

    # 5. Wait for the PipeWire socket to be available
    if ! wait_for_pipewire_socket; then
        yellow "⚠️ PipeWire socket not available. Skipping virtual device setup."
        return 0
    fi

    # 6. Create virtual audio devices
    blue "🎧 Creating virtual audio devices..."
    /usr/local/bin/create-virtual-pipewire-devices.sh || yellow "⚠️ Failed to create virtual audio devices"

    green "✅ PipeWire startup and configuration completed successfully."
}

main "$@"

