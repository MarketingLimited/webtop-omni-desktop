#!/bin/bash
# Create Virtual PipeWire Audio Devices Script
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

# Determine effective user and environment
if id "$DEV_USERNAME" >/dev/null 2>&1; then
    DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME")}" 
    HOME_DIR="$(getent passwd "$DEV_USERNAME" | cut -d: -f6)"
else
    yellow "⚠️  User '$DEV_USERNAME' not found. Using 'root'."
    DEV_USERNAME="root"
    DEV_UID=0
    HOME_DIR="/root"
fi

# Export environment variables for PipeWire
export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"
export HOME="${HOME_DIR}"
PIPEWIRE_WAIT_TIMEOUT="${PIPEWIRE_WAIT_TIMEOUT:-30}"

# Function to execute PipeWire commands
run_pw_cli() {
    if [ "$DEV_USERNAME" = "root" ]; then
        pw-cli "$@"
    else
        su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pw-cli $*"
    fi
}

# Wait for PipeWire to be ready
wait_for_pipewire() {
    local elapsed=0
    blue "⏳ Waiting for PipeWire to become ready..."
    
    # Ensure runtime directory exists
    mkdir -p "${XDG_RUNTIME_DIR}/pipewire"
    chown "${DEV_USERNAME}:${DEV_USERNAME}" "${XDG_RUNTIME_DIR}" 2>/dev/null || true
    chmod 700 "${XDG_RUNTIME_DIR}" 2>/dev/null || true
    
    until run_pw_cli info >/dev/null 2>&1; do
        if [ "$elapsed" -ge "$PIPEWIRE_WAIT_TIMEOUT" ]; then
            red "❌ PipeWire did not become ready within ${PIPEWIRE_WAIT_TIMEOUT}s."
            red "Debug: XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR, DEV_USERNAME=$DEV_USERNAME"
            return 1
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        blue "Waiting... (${elapsed}s/${PIPEWIRE_WAIT_TIMEOUT}s)"
    done
    green "✅ PipeWire is ready."
}

# Function to create a virtual audio device
create_virtual_device() {
    local device_name="$1"
    local description="$2"

    if run_pw_cli list-objects | grep -q "$device_name"; then
        green "✅ Virtual device '$device_name' already exists."
        return 0
    fi

    yellow "🔧 Creating virtual device '$device_name'..."
    
    # Try method 1: Using pw-cli create-node
    if run_pw_cli create-node adapter '{ factory.name=support.null-audio-sink node.name="'$device_name'" node.description="'$description'" media.class=Audio/Sink audio.channels=2 audio.position="[FL,FR]" }'; then
        green "✅ Virtual device '$device_name' created successfully (method 1)."
        return 0
    fi
    
    # Try method 2: Alternative syntax
    yellow "⚠️  Method 1 failed, trying alternative approach..."
    if run_pw_cli create-node adapter factory.name=support.null-audio-sink node.name="$device_name" node.description="$description" media.class=Audio/Sink audio.channels=2; then
        green "✅ Virtual device '$device_name' created successfully (method 2)."
        return 0
    fi
    
    red "❌ Failed to create virtual device '$device_name' with all methods."
    return 1
}

# Function to wait for WirePlumber
wait_for_wireplumber() {
    local elapsed=0
    blue "⏳ Waiting for WirePlumber to become ready..."
    
    local wpctl_cmd="wpctl status"
    if [ "$DEV_USERNAME" != "root" ]; then
        wpctl_cmd="su - ${DEV_USERNAME} -c 'export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; wpctl status'"
    fi
    
    until eval "$wpctl_cmd" >/dev/null 2>&1; do
        if [ "$elapsed" -ge "20" ]; then
            yellow "⚠️  WirePlumber not ready after 20s, continuing anyway..."
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    green "✅ WirePlumber is ready."
}

# Main function
main() {
    blue "🎧 Creating virtual audio devices..."

    if ! wait_for_pipewire; then
        red "❌ PipeWire not available, cannot proceed"
        return 1
    fi
    
    # Wait for WirePlumber too
    wait_for_wireplumber

    # Create the virtual devices
    if create_virtual_device "virtual_speaker" "Virtual Marketing Speaker" && \
       create_virtual_device "virtual_microphone" "Virtual Marketing Microphone"; then
        
        green "✅ Virtual audio device setup completed successfully."
        
        # Show created devices
        blue "📋 Listing PipeWire objects:"
        run_pw_cli list-objects | grep -E "(virtual_speaker|virtual_microphone)" || yellow "⚠️  No virtual devices found in list"
        
        return 0
    else
        red "❌ Failed to create one or more virtual devices"
        return 1
    fi
}

main "$@"
