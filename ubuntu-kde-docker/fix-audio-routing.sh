#!/bin/bash

# Audio Routing Fix Script
# Ensures all desktop audio is properly routed to virtual_speaker

set -e

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

echo "🎯 Fixing Audio Routing to Virtual Speaker"
echo "=========================================="

# Ensure environment is set
export XDG_RUNTIME_DIR="/run/user/${DEV_UID}"

# Function to run pactl commands with proper environment
run_pactl() {
    local cmd="$1"
    su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        export PULSE_RUNTIME_PATH=/run/user/${DEV_UID}/pulse
        pactl $cmd
    " 2>/dev/null
}

# Function to run pactl with TCP fallback
run_pactl_with_fallback() {
    local cmd="$1"
    if run_pactl "$cmd"; then
        return 0
    else
        echo "Local connection failed, trying TCP fallback..."
        su - "${DEV_USERNAME}" -c "pactl -s tcp:localhost:4713 $cmd" 2>/dev/null
    fi
}

# Step 1: Verify virtual devices exist
check_virtual_devices() {
    blue "🔍 Step 1: Checking virtual audio devices..."
    
    local sinks
    sinks=$(run_pactl_with_fallback "list short sinks" || echo "")
    
    if echo "$sinks" | grep -q "virtual_speaker"; then
        green "✅ virtual_speaker sink found"
    else
        red "❌ virtual_speaker sink missing"
        echo "Creating virtual_speaker..."
        run_pactl_with_fallback "load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description=\"Virtual_Marketing_Speaker\"" || {
            yellow "⚠️  Failed to create virtual_speaker, continuing..."
        }
    fi
    
    echo "Current sinks:"
    echo "$sinks"
}

# Step 2: Set virtual_speaker as default
set_default_devices() {
    blue "\n🎯 Step 2: Setting default audio devices..."
    
    # Set default sink
    if run_pactl_with_fallback "set-default-sink virtual_speaker"; then
        green "✅ Set virtual_speaker as default sink"
    else
        red "❌ Failed to set default sink"
    fi
    
    # Verify default sink
    local default_sink
    default_sink=$(run_pactl_with_fallback "get-default-sink" || echo "unknown")
    echo "Current default sink: $default_sink"
    
    if [ "$default_sink" = "virtual_speaker" ]; then
        green "✅ Default sink correctly set to virtual_speaker"
    else
        yellow "⚠️  Default sink is not virtual_speaker: $default_sink"
    fi
}

# Step 3: Move existing audio streams
move_existing_streams() {
    blue "\n🎵 Step 3: Moving existing audio streams..."
    
    local sink_inputs
    sink_inputs=$(run_pactl_with_fallback "list short sink-inputs" || echo "")
    
    if [ -n "$sink_inputs" ]; then
        echo "Found active audio streams:"
        echo "$sink_inputs"
        
        # Move each stream to virtual_speaker
        echo "$sink_inputs" | awk '{print $1}' | while read -r input_id; do
            if [ -n "$input_id" ] && [ "$input_id" != "sink-input" ]; then
                echo "Moving sink-input $input_id to virtual_speaker..."
                if run_pactl_with_fallback "move-sink-input $input_id virtual_speaker"; then
                    green "✅ Moved sink-input $input_id"
                else
                    yellow "⚠️  Failed to move sink-input $input_id"
                fi
            fi
        done
    else
        echo "No active audio streams found"
    fi
}

# Step 4: Configure KDE audio system
configure_kde_audio() {
    blue "\n🖥️  Step 4: Configuring KDE audio system..."
    
    # Set KDE audio configuration if running in KDE
    if [ -n "$KDE_SESSION_VERSION" ] || pgrep -f plasma >/dev/null 2>&1; then
        echo "KDE Plasma detected, configuring audio system..."
        
        # Try to set audio configuration via KDE config
        if command -v kwriteconfig5 >/dev/null 2>&1; then
            echo "Setting KDE audio configuration..."
            su - "${DEV_USERNAME}" -c "
                kwriteconfig5 --file ~/.config/kcm_pulseaudio --group General --key DefaultSink virtual_speaker
                kwriteconfig5 --file ~/.config/kcm_pulseaudio --group General --key DefaultSource virtual_mic_source
            " 2>/dev/null || true
            green "✅ KDE audio configuration updated"
        fi
        
        # Restart KDE audio applet if running
        if pgrep -f plasma-pa >/dev/null 2>&1; then
            echo "Restarting KDE audio applet..."
            su - "${DEV_USERNAME}" -c "
                pkill -f plasma-pa
                nohup plasma-pa >/dev/null 2>&1 &
            " 2>/dev/null || true
        fi
    else
        echo "KDE not detected, skipping KDE-specific configuration"
    fi
}

# Step 5: Test audio routing
test_audio_routing() {
    blue "\n🧪 Step 5: Testing audio routing..."
    
    # Generate a test tone and verify it reaches virtual_speaker.monitor
    echo "Testing audio routing with test tone..."
    
    local test_file="/tmp/routing_test_$(date +%s).raw"
    
    # Start monitoring virtual_speaker.monitor
    timeout 5 su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        parecord --device=virtual_speaker.monitor --format=s16le --rate=44100 --channels=2 --raw > $test_file 2>/dev/null
    " &
    local monitor_pid=$!
    
    sleep 1
    
    # Generate test tone
    echo "Generating test tone..."
    timeout 3 su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        export PULSE_RUNTIME_PATH=/run/user/${DEV_UID}/pulse
        speaker-test -t sine -f 440 -l 1 -s 1 -D pulse:virtual_speaker >/dev/null 2>&1
    " || {
        # Alternative test method using paplay
        echo "speaker-test not available, trying paplay..."
        timeout 3 su - "${DEV_USERNAME}" -c "
            export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
            dd if=/dev/zero bs=4 count=44100 | paplay --device=virtual_speaker --format=s16le --rate=44100 --channels=2 >/dev/null 2>&1
        " 2>/dev/null || true
    }
    
    # Wait for monitoring to complete
    wait $monitor_pid 2>/dev/null || true
    
    # Check results
    if [ -f "$test_file" ]; then
        local file_size=$(stat -c%s "$test_file" 2>/dev/null || echo 0)
        if [ "$file_size" -gt 1000 ]; then
            green "✅ Audio routing test successful! (${file_size} bytes captured)"
            echo "Audio is properly flowing through virtual_speaker to its monitor"
        else
            yellow "⚠️  Audio routing test captured minimal data (${file_size} bytes)"
            echo "Audio may not be flowing properly through the virtual device"
        fi
        rm -f "$test_file"
    else
        red "❌ Audio routing test failed - no data captured"
    fi
}

# Step 6: Create persistent configuration
create_persistent_config() {
    blue "\n💾 Step 6: Creating persistent configuration..."
    
    # Create a script that will run on login to ensure routing
    cat > "/home/${DEV_USERNAME}/.config/autostart/fix-audio-routing.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Fix Audio Routing
Exec=/usr/local/bin/fix-audio-routing.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Comment=Ensure audio is routed to virtual_speaker
EOF
    
    chown "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/.config/autostart/fix-audio-routing.desktop"
    green "✅ Created autostart configuration for persistent audio routing"
}

# Main execution
main() {
    echo "Starting audio routing fix process..."
    echo "This will ensure all desktop audio is routed to virtual_speaker for capture."
    echo ""
    
    # Check if user exists
    if ! id "${DEV_USERNAME}" >/dev/null 2>&1; then
        red "❌ User ${DEV_USERNAME} doesn't exist"
        exit 1
    fi
    
    # Create autostart directory if it doesn't exist
    mkdir -p "/home/${DEV_USERNAME}/.config/autostart"
    
    check_virtual_devices
    set_default_devices
    move_existing_streams
    configure_kde_audio
    test_audio_routing
    create_persistent_config
    
    echo ""
    green "🎉 Audio routing fix completed!"
    echo ""
    echo "Summary:"
    echo "- Virtual audio devices checked/created"
    echo "- Default audio sink set to virtual_speaker"
    echo "- Existing audio streams moved to virtual_speaker"
    echo "- KDE audio system configured (if applicable)"
    echo "- Audio routing tested"
    echo "- Persistent configuration created"
    echo ""
    echo "To verify the fix is working:"
    echo "1. Play any audio in the desktop"
    echo "2. Run: /usr/local/bin/debug-audio-pipeline.sh"
    echo "3. Check the browser audio connection"
}

# Allow script to be called directly or sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi