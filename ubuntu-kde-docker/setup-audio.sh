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

# Create ALSA loopback device if not exists
if ! lsmod | grep -q snd_aloop; then
    modprobe snd-aloop || echo "⚠️  Could not load snd-aloop module (may need privileged mode)"
fi

# Create audio test script
cat <<'EOF' > /usr/local/bin/test-audio.sh
#!/bin/bash
echo "🔊 Testing audio system..."
echo "Available audio sinks:"
pulseaudio --check -v || echo "PulseAudio not running"
pactl list short sinks 2>/dev/null || echo "No sinks found"
echo "Testing audio generation..."
speaker-test -t sine -f 1000 -l 1 -s 1 2>/dev/null || echo "Speaker test failed"
echo "Audio test complete!"
EOF

chmod +x /usr/local/bin/test-audio.sh

echo "✅ Audio system setup complete"