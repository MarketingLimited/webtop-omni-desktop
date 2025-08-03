#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"

echo "🔊 Setting up audio system..."

# Determine if user exists to handle build vs runtime
if id "$DEV_USERNAME" >/dev/null 2>&1; then
    IS_RUNTIME=true
    DEV_UID="$(id -u "$DEV_USERNAME")"
    echo "🔧 Runtime mode: applying user configuration"
else
    IS_RUNTIME=false
    echo "🔧 Build mode: system-wide configuration only"
fi

# Create runtime directories (safe for build)
mkdir -p "/run/user/${DEV_UID}/pulse"
if [ "$IS_RUNTIME" = true ]; then
    chown "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}" "/run/user/${DEV_UID}/pulse"
    chmod 700 "/run/user/${DEV_UID}"
fi

# System-wide ALSA configuration with PulseAudio fallback
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
EOF

# User-specific PulseAudio configuration
if [ "$IS_RUNTIME" = true ]; then
    mkdir -p "/home/${DEV_USERNAME}/.config/pulse"
    cat <<EOF > "/home/${DEV_USERNAME}/.config/pulse/default.pa"
# Core protocols with anonymous authentication
load-module module-native-protocol-unix auth-anonymous=1 socket=/run/user/${DEV_UID}/pulse/native
load-module module-native-protocol-tcp auth-anonymous=1 port=4713 listen=0.0.0.0

# Virtual devices
load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description="Virtual_Marketing_Speaker"
load-module module-null-sink sink_name=virtual_microphone sink_properties=device.description="Virtual_Marketing_Microphone"
load-module module-virtual-source source_name=virtual_mic_source master=virtual_microphone.monitor source_properties=device.description="Virtual_Marketing_Mic_Source"

# Defaults
set-default-sink virtual_speaker
set-default-source virtual_mic_source
set-sink-volume virtual_speaker 32768
set-sink-volume virtual_microphone 32768

# Fallback devices
load-module module-null-sink sink_name=fallback_speaker sink_properties=device.description="Fallback_Speaker"
load-module module-null-sink sink_name=fallback_microphone sink_properties=device.description="Fallback_Microphone"
EOF

    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/.config"
fi

echo "✅ Audio system setup complete"

