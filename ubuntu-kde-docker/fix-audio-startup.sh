#!/bin/bash
# Audio Startup Fix Script - Run during container initialization
# Ensures proper audio system initialization for containers

set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
# Determine the correct UID at runtime. Fall back to 1000 if the user doesn't exist yet
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

echo "🔧 Fixing audio system startup configuration..."

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

# Check if we're running during build (user doesn't exist yet) or runtime
if id "$DEV_USERNAME" >/dev/null 2>&1; then
    IS_RUNTIME=true
    blue "🔧 Runtime mode: Setting user-specific permissions"
else
    IS_RUNTIME=false
    blue "🔧 Build mode: Skipping user-specific operations"
fi

# Ensure runtime directories exist (build-safe)
mkdir -p "/run/user/${DEV_UID}"
mkdir -p "/run/user/${DEV_UID}/pulse"
if [ "$IS_RUNTIME" = true ]; then
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}"
    chmod 700 "/run/user/${DEV_UID}"
fi

# Create systemd-style runtime directory structure
mkdir -p "/run/user/${DEV_UID}/systemd"
if [ "$IS_RUNTIME" = true ]; then
    chown "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}/systemd"

    # Ensure PulseAudio config directory exists
    mkdir -p "/home/${DEV_USERNAME}/.config/pulse"
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/.config"
fi

# Create optimized PulseAudio client configuration (runtime only)
if [ "$IS_RUNTIME" = true ]; then
    cat <<EOF > "/home/${DEV_USERNAME}/.config/pulse/client.conf"
# Container-optimized PulseAudio client configuration
default-server = unix:/run/user/${DEV_UID}/pulse/native
enable-shm = no
enable-memfd = no
auto-connect-localhost = yes
auto-connect-display = yes
EOF

    # Create ALSA configuration that properly connects to PulseAudio
    cat <<EOF > "/home/${DEV_USERNAME}/.asoundrc"
# Container-optimized ALSA configuration
pcm.!default {
    type pulse
    hint {
        show on
        description "PulseAudio Sound Server"
    }
}

ctl.!default {
    type pulse
}

# Fallback to null device if PulseAudio unavailable
pcm.fallback {
    type null
    hint {
        show on
        description "Fallback Null Device"
    }
}
EOF

    chown "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/.asoundrc"
    chown "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/.config/pulse/client.conf"
fi

# Set proper permissions for audio devices if they exist (runtime only)
if [ "$IS_RUNTIME" = true ] && [ -d "/dev/snd" ]; then
    chown -R root:audio /dev/snd
    chmod -R g+rw /dev/snd
    usermod -a -G audio "${DEV_USERNAME}" 2>/dev/null || true
fi

# Ensure virtual audio device creation (runtime only)
if [ "$IS_RUNTIME" = true ]; then
    green "🔊 Ensuring virtual audio devices are ready..."
    
    # Wait briefly for PulseAudio to initialize
    sleep 2
    
    # Verify and create virtual devices if needed
    if ! su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sinks" 2>/dev/null | grep -q virtual_speaker; then
        yellow "⚠️  Virtual speaker not found, triggering device creation..."
        /usr/local/bin/create-virtual-audio-devices.sh &
    else
        green "✅ Virtual audio devices already present"
    fi
fi

green "✅ Audio system startup configuration completed"