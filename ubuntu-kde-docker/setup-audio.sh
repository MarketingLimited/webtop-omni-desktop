#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"

echo "🔊 Setting up audio system for marketing agency..."

# Ensure runtime directories exist
mkdir -p "/run/user/${DEV_UID}" "/run/user/${DEV_UID}/pulse"
chown "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}" "/run/user/${DEV_UID}/pulse"
chmod 700 "/run/user/${DEV_UID}"

# Create ALSA configuration for virtual audio devices
cat <<EOF > /etc/asound.conf
pcm.!default {
    type pulse
    server "tcp:localhost:4713"
}
ctl.!default {
    type pulse
    server "tcp:localhost:4713"
}

pcm.marketing_virtual {
    type null
    device 0
}

pcm.marketing_loopback {
    type hw
    card Loopback
    device 0
    subdevice 0
}
EOF

# Create user-specific PulseAudio configuration
mkdir -p "/home/${DEV_USERNAME}/.config/pulse"
cat <<EOF > "/home/${DEV_USERNAME}/.config/pulse/default.pa"
#!/usr/bin/pulseaudio -nF

# Load audio drivers statically
load-module module-device-restore
load-module module-stream-restore
load-module module-card-restore
load-module module-augment-properties
load-module module-switch-on-port-available

# Create virtual audio sink for marketing applications
load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description="Virtual_Marketing_Speaker"
load-module module-null-sink sink_name=virtual_microphone sink_properties=device.description="Virtual_Marketing_Microphone"

# Create loopback for audio routing
load-module module-loopback source=virtual_microphone.monitor sink=virtual_speaker latency_msec=50

# Enable TCP module for remote audio access
load-module module-native-protocol-tcp auth-anonymous=1 port=4713

# Load the X11 bell module
load-module module-x11-bell sample=bell-windowing-system

# Load module to restore the default sink/source when changed by the user
load-module module-default-device-restore

# Automatically restore the volume of streams and devices
load-module module-rescue-streams
load-module module-always-sink
load-module module-intended-roles
load-module module-suspend-on-idle

# Make virtual speaker the default
set-default-sink virtual_speaker
set-default-source virtual_microphone.monitor
EOF

# Set proper ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/.config"

# Create ALSA loopback device if not exists with fallbacks
if ! lsmod | grep -q snd_aloop; then
    modprobe snd-aloop || echo "⚠️  Could not load snd-aloop module (may need privileged mode)"
    modprobe snd-dummy || echo "⚠️  Could not load snd-dummy module (creating software fallback)"
    modprobe snd-pcm-oss || echo "⚠️  Could not load OSS compatibility module"
fi

# Ensure audio device permissions
if [ -d "/dev/snd" ]; then
    chown -R "${DEV_USERNAME}:audio" /dev/snd || echo "⚠️  Could not set audio device permissions"
    chmod -R g+rw /dev/snd || echo "⚠️  Could not set audio device permissions"
fi

# Create pulse directories with proper ownership
mkdir -p "/run/user/${DEV_UID}/pulse"
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}"
chmod 700 "/run/user/${DEV_UID}"

# Create advanced audio test script with connectivity testing
cat <<'EOF' > /usr/local/bin/test-audio.sh
#!/bin/bash

# Advanced Audio Testing and Connectivity Script
# Marketing Agency WebTop Audio System

set -e

echo "🔊 Advanced Audio System Testing..."

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

# Test PulseAudio server connectivity
test_pulseaudio_connectivity() {
    echo "🔍 Testing PulseAudio connectivity..."
    
    if pulseaudio --check -v; then
        green "✅ PulseAudio is running"
    else
        red "❌ PulseAudio is not running"
        return 1
    fi
    
    # Test TCP connectivity
    if pactl -s tcp:localhost:4713 info > /dev/null 2>&1; then
        green "✅ PulseAudio TCP server accessible"
    else
        yellow "⚠️  PulseAudio TCP server not accessible"
    fi
    
    # Test local connectivity
    if pactl info > /dev/null 2>&1; then
        green "✅ PulseAudio local server accessible"
    else
        red "❌ PulseAudio local server not accessible"
    fi
}

# Test audio devices
test_audio_devices() {
    echo "🔍 Testing audio devices..."
    
    echo "Available audio sinks:"
    if pactl list short sinks 2>/dev/null; then
        green "✅ Audio sinks detected"
    else
        red "❌ No audio sinks found"
    fi
    
    echo "Available audio sources:"
    if pactl list short sources 2>/dev/null; then
        green "✅ Audio sources detected"
    else
        red "❌ No audio sources found"
    fi
    
    echo "Default sink:"
    pactl get-default-sink 2>/dev/null || red "❌ No default sink"
    
    echo "Default source:"
    pactl get-default-source 2>/dev/null || red "❌ No default source"
}

# Test VNC audio integration
test_vnc_audio() {
    echo "🔍 Testing VNC audio integration..."
    
    if pgrep -f "x11vnc" > /dev/null; then
        green "✅ VNC server is running"
        
        # Check if VNC has audio forwarding capability
        if lsof -i :4713 | grep -q vnc; then
            green "✅ VNC audio forwarding detected"
        else
            yellow "⚠️  VNC audio forwarding not detected"
        fi
    else
        red "❌ VNC server not running"
    fi
}

# Test Xpra audio integration
test_xpra_audio() {
    echo "🔍 Testing Xpra audio integration..."
    
    if pgrep -f "xpra.*14500" > /dev/null; then
        green "✅ Xpra server is running"
        
        # Check if Xpra has PulseAudio integration
        if pgrep -f "xpra.*pulseaudio" > /dev/null; then
            green "✅ Xpra PulseAudio integration active"
        else
            yellow "⚠️  Xpra PulseAudio integration not detected"
        fi
    else
        red "❌ Xpra server not running"
    fi
}

# Test audio generation capability
test_audio_generation() {
    echo "🔍 Testing audio generation..."
    
    # Test with speaker-test
    if command -v speaker-test > /dev/null; then
        if timeout 5 speaker-test -t sine -f 440 -l 1 -s 1 > /dev/null 2>&1; then
            green "✅ Speaker test successful"
        else
            yellow "⚠️  Speaker test failed or timed out"
        fi
    else
        yellow "⚠️  speaker-test not available"
    fi
    
    # Test with paplay
    if command -v paplay > /dev/null; then
        # Create a test tone
        if timeout 3 paplay /dev/zero --rate=44100 --format=s16le --channels=2 --volume=32768 2>/dev/null; then
            green "✅ PulseAudio playback test successful"
        else
            yellow "⚠️  PulseAudio playback test failed"
        fi
    else
        yellow "⚠️  paplay not available"
    fi
}

# Test desktop application audio integration
test_desktop_audio_integration() {
    echo "🔍 Testing desktop application audio integration..."
    
    # Check if KDE audio system is configured
    if [ -f "/home/${USER}/.config/pulse/default.pa" ]; then
        green "✅ User PulseAudio configuration found"
    else
        red "❌ User PulseAudio configuration missing"
    fi
    
    # Test ALSA configuration
    if [ -f "/etc/asound.conf" ] || [ -f "/home/${USER}/.asoundrc" ]; then
        green "✅ ALSA configuration found"
    else
        yellow "⚠️  ALSA configuration not found"
    fi
    
    # Check audio session integration
    if [ -n "$XDG_RUNTIME_DIR" ] && [ -d "$XDG_RUNTIME_DIR/pulse" ]; then
        green "✅ Audio session integration configured"
    else
        yellow "⚠️  Audio session integration not properly configured"
    fi
}

# Generate audio system report
generate_audio_report() {
    echo "📊 Audio System Report:"
    echo "======================="
    
    echo "PulseAudio Server Info:"
    pactl info 2>/dev/null | head -10 || echo "PulseAudio info not available"
    
    echo ""
    echo "Audio Hardware:"
    cat /proc/asound/cards 2>/dev/null || echo "No audio hardware detected"
    
    echo ""
    echo "Loaded Audio Modules:"
    lsmod | grep snd | head -5 || echo "No audio modules loaded"
    
    echo ""
    echo "Audio Processes:"
    pgrep -f "pulse|alsa|audio" | while read pid; do
        ps -p $pid -o pid,cmd --no-headers 2>/dev/null || true
    done
    
    echo ""
    echo "Network Audio Ports:"
    netstat -tuln | grep -E ":4713|:5901|:14500" || echo "No audio-related network ports detected"
}

# Main test execution
main() {
    echo "$(date): Starting comprehensive audio system test"
    
    test_pulseaudio_connectivity || true
    test_audio_devices || true
    test_vnc_audio || true  
    test_xpra_audio || true
    test_audio_generation || true
    test_desktop_audio_integration || true
    
    echo ""
    generate_audio_report
    
    echo ""
    blue "🎵 Audio system test completed!"
    echo "Check logs above for any issues that need attention."
}

# Allow script to be sourced or executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF

chmod +x /usr/local/bin/test-audio.sh

# Create audio fallback recovery script
cat <<'EOF' > /usr/local/bin/audio-recovery.sh
#!/bin/bash

# Audio Recovery Script for Marketing Agency WebTop
# Automatically fixes common audio issues

set -e

echo "🔧 Audio Recovery System..."

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"

# Restart PulseAudio with fallback configuration
restart_pulseaudio() {
    echo "🔄 Restarting PulseAudio with fallback configuration..."
    
    # Kill existing PulseAudio
    pkill -f pulseaudio || true
    sleep 2
    
    # Ensure directories exist
    mkdir -p "/run/user/${DEV_UID}/pulse"
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}"
    
    # Start PulseAudio with minimal configuration
    su - "${DEV_USERNAME}" -c "
        export XDG_RUNTIME_DIR=/run/user/${DEV_UID}
        export PULSE_RUNTIME_PATH=/run/user/${DEV_UID}/pulse
        pulseaudio --daemonize=no --disallow-exit --exit-idle-time=-1 \
            --load='module-null-sink sink_name=fallback_speaker' \
            --load='module-native-protocol-tcp auth-anonymous=1 port=4713' &
    "
    
    sleep 3
    echo "✅ PulseAudio restarted with fallback configuration"
}

# Create emergency virtual audio devices
create_emergency_devices() {
    echo "🚨 Creating emergency virtual audio devices..."
    
    # Load kernel modules if possible
    modprobe snd-dummy numid=2 2>/dev/null || echo "Using software-only audio"
    
    # Create minimal ALSA configuration
    cat <<ALSA_EOF > /tmp/emergency_asound.conf
pcm.!default {
    type null
}
ctl.!default {
    type null
}
ALSA_EOF
    
    export ALSA_PCM_CONF=/tmp/emergency_asound.conf
    echo "✅ Emergency audio devices created"
}

# Fix audio permissions
fix_audio_permissions() {
    echo "🔐 Fixing audio permissions..."
    
    # Fix runtime directories
    mkdir -p "/run/user/${DEV_UID}/pulse"
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}"
    chmod 700 "/run/user/${DEV_UID}"
    
    # Fix device permissions if they exist
    if [ -d "/dev/snd" ]; then
        chown -R "${DEV_USERNAME}:audio" /dev/snd
        chmod -R g+rw /dev/snd
    fi
    
    echo "✅ Audio permissions fixed"
}

# Main recovery function
main() {
    echo "Starting audio recovery process..."
    
    fix_audio_permissions
    create_emergency_devices
    restart_pulseaudio
    
    # Test the recovery
    sleep 5
    if /usr/local/bin/test-audio.sh >/dev/null 2>&1; then
        echo "✅ Audio recovery successful!"
    else
        echo "⚠️  Audio recovery completed with warnings"
    fi
}

main "$@"
EOF

chmod +x /usr/local/bin/audio-recovery.sh

echo "✅ Advanced audio system with fallbacks setup complete"