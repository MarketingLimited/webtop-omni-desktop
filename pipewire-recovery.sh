#!/bin/bash
# PipeWire Recovery Script
# Handles PipeWire service failures and attempts recovery

set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"
export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

echo "🔧 PipeWire Recovery Script Starting..."

# Function to run commands as the dev user
run_as_user() {
    su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; $*"
}

# Check if PipeWire is running
check_pipewire_status() {
    if run_as_user "pw-cli info" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check if WirePlumber is running
check_wireplumber_status() {
    if run_as_user "wpctl status" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Clean up PipeWire processes
cleanup_pipewire() {
    echo "🧹 Cleaning up PipeWire processes..."
    
    # Kill existing processes
    pkill -f pipewire || true
    pkill -f wireplumber || true
    
    # Wait for processes to terminate
    sleep 3
    
    # Clean up runtime sockets
    rm -f "/run/user/${DEV_UID}/pipewire-0" || true
    rm -f "/run/user/${DEV_UID}/pipewire-0.lock" || true
    
    # Ensure runtime directory exists with correct permissions
    mkdir -p "/run/user/${DEV_UID}/pipewire"
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}"
    chmod 700 "/run/user/${DEV_UID}"
    
    green "✅ PipeWire cleanup completed"
}

# Start PipeWire service
start_pipewire() {
    echo "🚀 Starting PipeWire..."
    
    # Start PipeWire as user
    if run_as_user "nohup pipewire > /tmp/pipewire.log 2>&1 &"; then
        sleep 3
        if check_pipewire_status; then
            green "✅ PipeWire started successfully"
            return 0
        else
            red "❌ PipeWire failed to start"
            return 1
        fi
    else
        red "❌ Failed to execute PipeWire startup command"
        return 1
    fi
}

# Start WirePlumber service
start_wireplumber() {
    echo "🚀 Starting WirePlumber..."
    
    # Wait for PipeWire socket
    local timeout=15
    local count=0
    
    while [ ! -e "/run/user/${DEV_UID}/pipewire-0" ] && [ $count -lt $timeout ]; do
        sleep 1
        count=$((count + 1))
    done
    
    if [ ! -e "/run/user/${DEV_UID}/pipewire-0" ]; then
        red "❌ PipeWire socket not available for WirePlumber"
        return 1
    fi
    
    # Start WirePlumber as user
    if run_as_user "nohup wireplumber > /tmp/wireplumber.log 2>&1 &"; then
        sleep 5
        if check_wireplumber_status; then
            green "✅ WirePlumber started successfully"
            return 0
        else
            red "❌ WirePlumber failed to start"
            return 1
        fi
    else
        red "❌ Failed to execute WirePlumber startup command"
        return 1
    fi
}

# Create virtual devices after services are running
create_virtual_devices() {
    echo "🎧 Creating virtual audio devices..."
    
    # Wait a bit for services to stabilize
    sleep 5
    
    if [ -f "/usr/local/bin/create-virtual-pipewire-devices.sh" ]; then
        if /usr/local/bin/create-virtual-pipewire-devices.sh; then
            green "✅ Virtual devices created successfully"
            return 0
        else
            yellow "⚠️  Virtual device creation had issues"
            return 1
        fi
    else
        red "❌ Virtual device creation script not found"
        return 1
    fi
}

# Main recovery function
perform_recovery() {
    local recovery_successful=true
    
    blue "🔄 Starting PipeWire recovery process..."
    
    # Step 1: Cleanup
    cleanup_pipewire
    
    # Step 2: Start PipeWire
    if ! start_pipewire; then
        recovery_successful=false
    fi
    
    # Step 3: Start WirePlumber (only if PipeWire started)
    if [ "$recovery_successful" = true ]; then
        if ! start_wireplumber; then
            recovery_successful=false
        fi
    fi
    
    # Step 4: Create virtual devices (only if both services started)
    if [ "$recovery_successful" = true ]; then
        create_virtual_devices || true  # Don't fail recovery if this fails
    fi
    
    if [ "$recovery_successful" = true ]; then
        green "✅ PipeWire recovery completed successfully"
        return 0
    else
        red "❌ PipeWire recovery failed"
        return 1
    fi
}

# Check current status
check_status() {
    echo "🔍 Checking current PipeWire status..."
    
    local pipewire_running=false
    local wireplumber_running=false
    
    if check_pipewire_status; then
        green "✅ PipeWire is running"
        pipewire_running=true
    else
        red "❌ PipeWire is not running"
    fi
    
    if check_wireplumber_status; then
        green "✅ WirePlumber is running"
        wireplumber_running=true
    else
        red "❌ WirePlumber is not running"
    fi
    
    if [ "$pipewire_running" = true ] && [ "$wireplumber_running" = true ]; then
        return 0
    else
        return 1
    fi
}

# Main execution
main() {
    case "${1:-check}" in
        "check")
            check_status
            ;;
        "recover")
            perform_recovery
            ;;
        "restart")
            cleanup_pipewire
            sleep 2
            perform_recovery
            ;;
        *)
            echo "Usage: $0 {check|recover|restart}"
            echo "  check   - Check current PipeWire status"
            echo "  recover - Attempt to recover failed services"
            echo "  restart - Force restart all PipeWire services"
            exit 1
            ;;
    esac
}

main "$@"