#!/bin/bash
# Fix noVNC Audio Connection Issues
# Addresses "Connection refused" errors for audio device "default"

set -euo pipefail

echo "🔧 Fixing noVNC Audio Connection Issues..."

DEV_USERNAME="${DEV_USERNAME:-devuser}"
# Determine the actual UID at runtime instead of assuming 1000
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

# Step 1: Kill any existing PulseAudio processes
fix_pulseaudio_processes() {
    echo "🔄 Cleaning up existing PulseAudio processes..."
    
    # Kill all PulseAudio processes
    pkill -f pulseaudio || true
    pkill -f pulse || true
    
    # Wait for processes to terminate
    sleep 3
    
    # Remove any stale socket files
    rm -rf /run/user/${DEV_UID}/pulse/* 2>/dev/null || true
    rm -rf /tmp/pulse-* 2>/dev/null || true
    
    green "✅ PulseAudio processes cleaned up"
}

# Step 2: Ensure proper runtime directories
setup_runtime_directories() {
    echo "📁 Setting up runtime directories..."
    
    # Create runtime directories
    mkdir -p "/run/user/${DEV_UID}"
    mkdir -p "/run/user/${DEV_UID}/pulse"
    
    # Set proper ownership and permissions
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}"
    chmod 700 "/run/user/${DEV_UID}"
    chmod 755 "/run/user/${DEV_UID}/pulse"
    
    # Set XDG_RUNTIME_DIR for the user
    echo "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}" >> "/home/${DEV_USERNAME}/.bashrc"
    
    green "✅ Runtime directories configured"
}

# Step 3: Create minimal PulseAudio configuration
create_minimal_pulse_config() {
    echo "⚙️ Creating minimal PulseAudio configuration..."
    
    # Remove conflicting user configuration and rely on system defaults
    mkdir -p "/home/${DEV_USERNAME}/.config/pulse"
    rm -f "/home/${DEV_USERNAME}/.config/pulse/default.pa" 2>/dev/null || true

    # Create client configuration without hardcoded server paths
    cat <<EOF > "/home/${DEV_USERNAME}/.config/pulse/client.conf"
# PulseAudio client configuration
autospawn = yes
daemon-binary = /usr/bin/pulseaudio
extra-arguments = --log-target=syslog --realtime-priority=5
EOF

    # Set proper ownership
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/.config/pulse"

    green "✅ PulseAudio configuration created"
}

# Step 4: Create ALSA configuration for default device
create_alsa_config() {
    echo "🔊 Creating ALSA configuration..."
    
    # System-wide ALSA configuration
    cat <<EOF > /etc/asound.conf
# ALSA configuration for container environment
pcm.!default {
    type pulse
    server "unix:/run/user/${DEV_UID}/pulse/native"
    fallback {
        type pulse
        server "tcp:localhost:4713"
    }
}

ctl.!default {
    type pulse
    server "unix:/run/user/${DEV_UID}/pulse/native"
    fallback {
        type pulse
        server "tcp:localhost:4713"
    }
}

# Null device fallback
pcm.null {
    type null
}

ctl.null {
    type null
}
EOF

    # User-specific ALSA configuration
    cat <<EOF > "/home/${DEV_USERNAME}/.asoundrc"
# User ALSA configuration
pcm.!default {
    type pulse
    server "unix:/run/user/${DEV_UID}/pulse/native"
    hint {
        show on
        description "PulseAudio Default"
    }
}

ctl.!default {
    type pulse
    server "unix:/run/user/${DEV_UID}/pulse/native"
}
EOF

    chown "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/.asoundrc"
    
    green "✅ ALSA configuration created"
}

# Step 5: Start PulseAudio with proper environment
start_pulseaudio() {
    echo "🚀 Starting PulseAudio..."
    
    # Start PulseAudio as the user with proper environment
    su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        export PULSE_RUNTIME_PATH=/run/user/${DEV_UID}/pulse
        pulseaudio --start --log-target=syslog --realtime-priority=5
    "
    
    # Wait for PulseAudio to start
    sleep 5
    
    # Verify PulseAudio is running
    if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl info" >/dev/null 2>&1; then
        green "✅ PulseAudio started successfully"
    else
        red "❌ PulseAudio failed to start"
        return 1
    fi
}

# Step 6: Verify and create virtual devices
verify_virtual_devices() {
    echo "🔍 Verifying virtual audio devices..."
    
    # Check for virtual devices
    if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sinks" | grep -q "virtual_speaker"; then
        green "✅ Virtual speaker found"
    else
        yellow "⚠️ Creating virtual speaker..."
        su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description=\"Virtual_Speaker\""
    fi
    
    if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sources" | grep -q "virtual_mic_source"; then
        green "✅ Virtual microphone found"
    else
        yellow "⚠️ Creating virtual microphone..."
        su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl load-module module-null-sink sink_name=virtual_microphone sink_properties=device.description=\"Virtual_Microphone\""
        su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl load-module module-virtual-source source_name=virtual_mic_source master=virtual_microphone.monitor source_properties=device.description=\"Virtual_Mic_Source\""
    fi
    
    # Set defaults
    su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl set-default-sink virtual_speaker"
    su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl set-default-source virtual_mic_source"
    
    green "✅ Virtual devices configured"
}

# Step 7: Test audio system
test_audio_system() {
    echo "🧪 Testing audio system..."
    
    # Test PulseAudio connectivity
    if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl info" >/dev/null 2>&1; then
        green "✅ PulseAudio connectivity test passed"
    else
        red "❌ PulseAudio connectivity test failed"
        return 1
    fi
    
    # Test TCP connectivity (for VNC)
    if su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl -s tcp:localhost:4713 info" >/dev/null 2>&1; then
        green "✅ PulseAudio TCP connectivity test passed"
    else
        yellow "⚠️ PulseAudio TCP connectivity test failed"
    fi
    
    # List available devices
    echo ""
    blue "📋 Available audio devices:"
    su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sinks"
    echo ""
    su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sources"
    
    green "✅ Audio system test completed"
}

# Step 8: Restart audio bridge if it exists
restart_audio_bridge() {
    echo "🌉 Restarting audio bridge..."
    
    # Kill existing audio bridge processes
    pkill -f "webrtc-audio-server" || true
    pkill -f "audio-bridge" || true
    
    # Wait for processes to terminate
    sleep 2
    
    # Start audio bridge if the script exists
    if [ -f "/usr/local/bin/webrtc-audio-server.cjs" ]; then
        nohup node /usr/local/bin/webrtc-audio-server.cjs > /var/log/audio-bridge.log 2>&1 &
        green "✅ Audio bridge restarted"
    elif [ -f "/opt/audio-bridge/webrtc-audio-server.cjs" ]; then
        nohup node /opt/audio-bridge/webrtc-audio-server.cjs > /var/log/audio-bridge.log 2>&1 &
        green "✅ Audio bridge restarted"
    else
        yellow "⚠️ Audio bridge script not found"
    fi
}

# Step 9: Create desktop audio test
create_desktop_test() {
    echo "🖥️ Creating desktop audio test..."
    
    cat <<'EOF' > "/home/${DEV_USERNAME}/Desktop/Test Audio.sh"
#!/bin/bash
# Desktop Audio Test

export XDG_RUNTIME_DIR=/run/user/1000

echo "🎵 Testing Audio System"
echo "======================="

echo "PulseAudio Info:"
pactl info | head -5

echo ""
echo "Available Sinks:"
pactl list short sinks

echo ""
echo "Available Sources:"
pactl list short sources

echo ""
echo "Default Sink:"
pactl get-default-sink

echo ""
echo "Default Source:"
pactl get-default-source

echo ""
echo "Testing audio playback (3 seconds)..."
if command -v speaker-test >/dev/null; then
    timeout 3 speaker-test -t sine -f 440 -l 1 -s 1 || true
    echo "Audio test completed!"
else
    echo "speaker-test not available"
fi

echo ""
echo "🎵 Audio test finished!"
EOF

    chmod +x "/home/${DEV_USERNAME}/Desktop/Test Audio.sh"
    chown "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/Desktop/Test Audio.sh"
    
    green "✅ Desktop audio test created"
}

# Main execution function
main() {
    echo "🔧 Starting noVNC Audio Fix..."
    echo "=============================="
    
    fix_pulseaudio_processes
    setup_runtime_directories
    create_minimal_pulse_config
    create_alsa_config
    start_pulseaudio
    verify_virtual_devices
    test_audio_system
    restart_audio_bridge
    create_desktop_test
    
    echo ""
    echo "🎉 noVNC Audio Fix Completed!"
    echo "============================="
    echo ""
    blue "Next steps:"
    echo "1. Refresh your noVNC browser page: http://37.27.49.246:32768/vnc_audio.html"
    echo "2. Click 'Connect Audio' in the noVNC interface"
    echo "3. Test audio by running the desktop test: ~/Desktop/Test Audio.sh"
    echo "4. Check KDE System Settings > Audio for available devices"
    echo ""
    green "✅ The 'Connection refused' error should now be resolved!"
}

# Run the fix
main "$@"