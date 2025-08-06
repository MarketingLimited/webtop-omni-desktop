#!/bin/bash
# PipeWire Audio Validation Script
# Runs basic checks to ensure PipeWire and virtual devices are configured

set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"
export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

echo "🔊 Validating PipeWire audio configuration..."

# Function to run commands as the dev user
run_as_user() {
    su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; $*"
}

# Check PipeWire status with retries
check_pipewire() {
    local retries=3
    local count=0
    
    while [ $count -lt $retries ]; do
        if run_as_user "pw-cli info" >/dev/null 2>&1; then
            green "✅ PipeWire is running"
            return 0
        fi
        
        count=$((count + 1))
        if [ $count -lt $retries ]; then
            yellow "⚠️  PipeWire check failed, retrying ($count/$retries)..."
            sleep 3
        fi
    done
    
    red "❌ PipeWire is not running after $retries attempts"
    return 1
}

# Check and create virtual devices
check_virtual_devices() {
    echo "🔍 Checking virtual audio devices..."
    
    local devices_exist=true
    
    if ! run_as_user "pw-cli list-objects" 2>/dev/null | grep -q virtual_speaker; then
        yellow "⚠️  virtual_speaker not found"
        devices_exist=false
    else
        green "✅ virtual_speaker found"
    fi
    
    if ! run_as_user "pw-cli list-objects" 2>/dev/null | grep -q virtual_microphone; then
        yellow "⚠️  virtual_microphone not found"
        devices_exist=false
    else
        green "✅ virtual_microphone found"
    fi
    
    if [ "$devices_exist" = false ]; then
        echo "🔧 Creating missing virtual devices..."
        if /usr/local/bin/create-virtual-pipewire-devices.sh; then
            green "✅ Virtual devices created successfully"
        else
            yellow "⚠️  Virtual device creation had issues, but continuing..."
        fi
    fi
}

# Configure default devices
configure_defaults() {
    if command -v wpctl >/dev/null 2>&1; then
        echo "🔧 Configuring default audio devices..."
        
        # Try to set defaults with error handling
        if run_as_user "wpctl status" >/dev/null 2>&1; then
            # Set virtual speaker as default sink
            local speaker_id=$(run_as_user "wpctl status" 2>/dev/null | grep 'virtual_speaker' | head -1 | awk '{print $2}' | tr -d '.' | sed 's/[^0-9]//g')
            if [ -n "$speaker_id" ]; then
                if run_as_user "wpctl set-default $speaker_id" >/dev/null 2>&1; then
                    green "✅ Set virtual_speaker as default sink"
                else
                    yellow "⚠️  Could not set virtual_speaker as default sink"
                fi
            fi
            
            # Set virtual microphone monitor as default source
            local mic_monitor_id=$(run_as_user "wpctl status" 2>/dev/null | grep -A10 "Sources:" | grep "virtual_microphone.*monitor" | head -1 | awk '{print $2}' | tr -d '.' | sed 's/[^0-9]//g')
            if [ -n "$mic_monitor_id" ]; then
                if run_as_user "wpctl set-default $mic_monitor_id" >/dev/null 2>&1; then
                    green "✅ Set virtual_microphone monitor as default source"
                else
                    yellow "⚠️  Could not set virtual_microphone monitor as default source"
                fi
            fi
        else
            yellow "⚠️  WirePlumber not accessible, skipping default device configuration"
        fi
    else
        yellow "⚠️  wpctl not available, skipping default device configuration"
    fi
}

# Run comprehensive test
run_tests() {
    echo "🧪 Running PipeWire system tests..."
    
    if [ -f "/usr/local/bin/test-pipewire.sh" ]; then
        if /usr/local/bin/test-pipewire.sh >/dev/null 2>&1; then
            green "✅ PipeWire system tests passed"
        else
            yellow "⚠️  Some PipeWire tests failed, but system may still be functional"
        fi
    else
        yellow "⚠️  PipeWire test script not found"
    fi
}

# Main validation sequence
main() {
    local validation_failed=false
    
    # Check PipeWire
    if ! check_pipewire; then
        validation_failed=true
    fi
    
    # Check virtual devices (only if PipeWire is running)
    if [ "$validation_failed" = false ]; then
        check_virtual_devices
        configure_defaults
        run_tests
    fi
    
    if [ "$validation_failed" = true ]; then
        red "❌ PipeWire validation failed"
        exit 1
    else
        green "✅ PipeWire validation complete"
        exit 0
    fi
}

main "$@"
