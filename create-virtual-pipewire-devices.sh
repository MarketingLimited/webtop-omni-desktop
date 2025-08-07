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
    until run_pw_cli info 0 >/dev/null 2>&1; do
        if [ "$elapsed" -ge "$PIPEWIRE_WAIT_TIMEOUT" ]; then
            red "❌ PipeWire did not become ready within ${PIPEWIRE_WAIT_TIMEOUT}s."
            return 1
        fi
        sleep 1
        elapsed=$((elapsed + 1))
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

    yellow "⚠️  Virtual device '$device_name' not found. Creating..."
    if run_pw_cli create-node adapter factory.name=support.null-audio-sink node.name="$device_name" node.description="$description" media.class=Audio/Sink audio.channels=2 audio.position=FL,FR; then
        green "✅ Virtual device '$device_name' created successfully."
    else
        red "❌ Failed to create virtual device '$device_name'."
        return 1
    fi
}

# Main function
main() {
    blue "🎧 Creating virtual audio devices..."

    if ! wait_for_pipewire; then
        return 1
    fi

    create_virtual_device "virtual_speaker" "Virtual Marketing Speaker"
    create_virtual_device "virtual_microphone" "Virtual Marketing Microphone"

    green "✅ Virtual audio device setup completed."
}

main "$@"
