#!/bin/bash
# PipeWire Startup Fix Script - Run during container initialization
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

echo "🔧 Fixing PipeWire system startup configuration..."

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
mkdir -p "/run/user/${DEV_UID}/pipewire"
if [ "$IS_RUNTIME" = true ]; then
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}"
    chmod 700 "/run/user/${DEV_UID}"
fi

# Create systemd-style runtime directory structure
mkdir -p "/run/user/${DEV_UID}/systemd"
if [ "$IS_RUNTIME" = true ]; then
    chown "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}/systemd"

    # Ensure PipeWire config directory exists
    mkdir -p "/home/${DEV_USERNAME}/.config/pipewire"
    mkdir -p "/home/${DEV_USERNAME}/.config/wireplumber"
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/.config"
fi

# Create optimized PipeWire client configuration (runtime only)
if [ "$IS_RUNTIME" = true ]; then
    cat <<EOF > "/home/${DEV_USERNAME}/.config/pipewire/client.conf"
# Container-optimized PipeWire client configuration
stream.properties = {
    node.latency             = 1024/44100
    resample.quality         = 4
    channelmix.normalize     = false
    channelmix.mix-lfe       = false
    audio.channels           = 2
    audio.rate               = 44100
    audio.format             = S16LE
}

context.properties = {
    log.level               = 2
    mem.warn-mlock          = false
    mem.allow-mlock         = false
    settings.check-quantum  = false
    settings.check-rate     = false
}
EOF

    # Create WirePlumber configuration
    cat <<EOF > "/home/${DEV_USERNAME}/.config/wireplumber/main.lua.d/99-virtual-devices.lua"
-- Virtual device configuration for container environment
virtual_speaker_rule = {
  matches = {
    {
      { "node.name", "equals", "virtual_speaker" },
    },
  },
  apply_properties = {
    ["audio.channels"] = 2,
    ["audio.rate"] = 44100,
    ["audio.format"] = "S16LE",
    ["node.description"] = "Virtual Marketing Speaker",
    ["device.class"] = "sound",
    ["media.class"] = "Audio/Sink",
    ["priority.driver"] = 1000,
    ["priority.session"] = 1000,
  },
}

virtual_microphone_rule = {
  matches = {
    {
      { "node.name", "equals", "virtual_microphone" },
    },
  },
  apply_properties = {
    ["audio.channels"] = 2,
    ["audio.rate"] = 44100,
    ["audio.format"] = "S16LE",
    ["node.description"] = "Virtual Marketing Microphone",
    ["device.class"] = "sound",
    ["media.class"] = "Audio/Sink",
    ["priority.driver"] = 1000,
    ["priority.session"] = 1000,
  },
}

table.insert(alsa_monitor.rules, virtual_speaker_rule)
table.insert(alsa_monitor.rules, virtual_microphone_rule)
EOF

    chown "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/.config/pipewire/client.conf"
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/.config/wireplumber"
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
    
    # Wait briefly for PipeWire to initialize
    sleep 2
    
    # Verify and create virtual devices if needed
    if ! su - "${DEV_USERNAME}" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pw-cli list-objects" 2>/dev/null | grep -q virtual_speaker; then
        yellow "⚠️  Virtual speaker not found, triggering device creation..."
        /usr/local/bin/create-virtual-pipewire-devices.sh &
    else
        green "✅ Virtual audio devices already present"
    fi
fi

green "✅ PipeWire system startup configuration completed"