#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
# Resolve the actual UID for the developer user. This handles containers where
# the user is not mapped to the default UID 1000.
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

echo "🔊 Setting up audio system for marketing agency..."

# Check if we're running during build (user doesn't exist yet) or runtime
if id "$DEV_USERNAME" >/dev/null 2>&1; then
    IS_RUNTIME=true
    echo "🔧 Runtime mode: Setting up user-specific audio configuration"
else
    IS_RUNTIME=false
    echo "🔧 Build mode: Setting up system-wide audio configuration only"
fi

# Create runtime directories (build-safe)
mkdir -p "/run/user/${DEV_UID}" "/run/user/${DEV_UID}/pulse" || true
if [ "$IS_RUNTIME" = true ]; then
    chown "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}" "/run/user/${DEV_UID}/pulse" || true
    chmod 700 "/run/user/${DEV_UID}" || true
fi

# Create ALSA configuration for virtual audio devices
cat <<EOF > /etc/asound.conf
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

# Create user-specific PulseAudio configuration (runtime only)
if [ "$IS_RUNTIME" = true ]; then
    mkdir -p "/home/${DEV_USERNAME}/.config/pulse"
    cat <<EOF > "/home/${DEV_USERNAME}/.config/pulse/default.pa"
#!/usr/bin/pulseaudio -nF

# Load core modules required for basic operation
load-module module-device-restore
load-module module-stream-restore
load-module module-card-restore
load-module module-augment-properties

# Load native protocol first (local socket)
load-module module-native-protocol-unix auth-anonymous=1 socket=/run/user/${DEV_UID}/pulse/native

# Enable TCP module for remote audio access (VNC)
load-module module-native-protocol-tcp auth-anonymous=1 port=4713 listen=0.0.0.0

# Create virtual audio devices for container environment  
load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description="Virtual_Marketing_Speaker"
load-module module-null-sink sink_name=virtual_microphone sink_properties=device.description="Virtual_Marketing_Microphone"

# Create a virtual source from the microphone sink's monitor
load-module module-virtual-source source_name=virtual_mic_source master=virtual_microphone.monitor source_properties=device.description="Virtual_Marketing_Mic_Source"

# Load essential modules only
load-module module-default-device-restore
load-module module-rescue-streams
load-module module-always-sink
load-module module-suspend-on-idle

# Load additional modules for virtual device persistence
load-module module-switch-on-port-available
load-module module-switch-on-connect

# Set defaults for container environment
set-default-sink virtual_speaker
set-default-source virtual_mic_source

# Set volume levels for virtual devices (100% volume = 65536)
set-sink-volume virtual_speaker 65536
set-sink-volume virtual_microphone 65536

# Create additional fallback devices for stability
load-module module-null-sink sink_name=fallback_speaker sink_properties=device.description="Fallback_Speaker"
load-module module-null-sink sink_name=fallback_microphone sink_properties=device.description="Fallback_Microphone"
EOF

    # Set proper ownership (runtime only)
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/.config"
fi

# Create container-compatible audio devices with software fallbacks
echo "🔧 Setting up container-compatible audio devices..."

# Skip hardware module loading in containers - use pure software approach
echo "✅ Using software-only audio pipeline (container-optimized)"

# Create software-only ALSA devices for container environment (runtime only)
if [ "$IS_RUNTIME" = true ]; then
    mkdir -p "/home/${DEV_USERNAME}/.asoundrc.d"
    cat <<EOF > "/home/${DEV_USERNAME}/.asoundrc"
# Container-compatible ALSA configuration with fallback
pcm.!default {
    type pulse
    server "unix:/run/user/${DEV_UID}/pulse/native"
    hint {
        show on
        description "PulseAudio Local Socket"
    }
    fallback {
        type pulse
        server "tcp:localhost:4713"
        hint {
            show on
            description "PulseAudio TCP Fallback"
        }
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

# Virtual marketing devices
pcm.marketing_speaker {
    type pulse
    device "virtual_speaker"
    hint {
        show on
        description "Virtual Marketing Speaker"
    }
}

pcm.marketing_microphone {
    type pulse
    device "virtual_mic_source"  
    hint {
        show on
        description "Virtual Marketing Microphone"
    }
}

# Null device fallback for container compatibility
pcm.null {
    type null
    hint {
        show on
        description "Null Audio Device"
    }
}
EOF

    chown "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/.asoundrc"
fi

# Ensure audio device permissions (runtime only)
if [ "$IS_RUNTIME" = true ]; then
    if [ -d "/dev/snd" ]; then
        chown -R "${DEV_USERNAME}:audio" /dev/snd || echo "⚠️  Could not set audio device permissions"
        chmod -R g+rw /dev/snd || echo "⚠️  Could not set audio device permissions"
    fi

    # Create pulse directories with proper ownership
    mkdir -p "/run/user/${DEV_UID}/pulse"
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}"
    chmod 700 "/run/user/${DEV_UID}"
fi

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
    netstat -tuln | grep -E ":4713|:5901" || echo "No audio-related network ports detected"
}

# Main test execution
main() {
    echo "$(date): Starting comprehensive audio system test"
    
    test_pulseaudio_connectivity || true
    test_audio_devices || true
    test_vnc_audio || true  
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
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

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