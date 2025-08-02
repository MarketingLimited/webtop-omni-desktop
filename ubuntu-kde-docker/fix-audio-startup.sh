#!/bin/bash
# Audio Startup Fix Script - Run during container initialization
# Ensures proper audio system initialization for containers

set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"

echo "🔧 Fixing audio system startup configuration..."

# Check if we're running during build (user doesn't exist yet) or runtime
if id "$DEV_USERNAME" >/dev/null 2>&1; then
    DEV_UID="$(id -u "$DEV_USERNAME")"
    IS_RUNTIME=true
    echo "🔧 Runtime mode: Setting user-specific permissions"
else
    IS_RUNTIME=false
    echo "🔧 Build mode: Skipping user-specific operations"
fi

# Ensure runtime directory structure exists (build-safe)
mkdir -p "/run/user/${DEV_UID}"/{pulse,systemd}

if [ "$IS_RUNTIME" = true ]; then
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}"
    chmod 700 "/run/user/${DEV_UID}"

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

    chown "${DEV_USERNAME}:${DEV_USERNAME}" \
        "/home/${DEV_USERNAME}/.asoundrc" \
        "/home/${DEV_USERNAME}/.config/pulse/client.conf"
fi

# Set proper permissions for audio devices if they exist (runtime only)
if [ "$IS_RUNTIME" = true ] && [ -d "/dev/snd" ]; then
    chown -R root:audio /dev/snd
    chmod -R g+rw /dev/snd
    usermod -a -G audio "${DEV_USERNAME}" 2>/dev/null || true
fi

echo "✅ Audio system startup configuration completed"
