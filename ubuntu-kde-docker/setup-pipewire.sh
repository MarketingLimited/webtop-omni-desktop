#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"

echo "🔊 Setting up PipeWire audio system..."

# Check if we're running during build (user doesn't exist yet) or runtime
if id "$DEV_USERNAME" >/dev/null 2>&1; then
    IS_RUNTIME=true
    echo "🔧 Runtime mode: Setting up user-specific PipeWire configuration"
else
    IS_RUNTIME=false
    echo "🔧 Build mode: Setting up system-wide PipeWire configuration only"
fi

# Create runtime directories (build-safe)
mkdir -p "/run/user/${DEV_UID}" "/run/user/${DEV_UID}/pipewire" || true
if [ "$IS_RUNTIME" = true ]; then
    chown "${DEV_USERNAME}:${DEV_USERNAME}" "/run/user/${DEV_UID}" "/run/user/${DEV_UID}/pipewire" || true
    chmod 700 "/run/user/${DEV_UID}" || true
fi

# Create PipeWire system configuration
mkdir -p /etc/pipewire
cat <<EOF > /etc/pipewire/pipewire.conf
# PipeWire system configuration for containerized environment
context.properties = {
    default.clock.rate          = 44100
    default.clock.quantum       = 1024
    default.clock.min-quantum   = 256
    default.clock.max-quantum   = 2048
    log.level                   = 2
    mem.warn-mlock              = false
    mem.allow-mlock             = false
    link.max-buffers            = 64
}

context.spa-libs = {
    audio.convert.* = audioconvert/libspa-audioconvert
    api.alsa.*      = alsa/libspa-alsa
    api.v4l2.*      = v4l2/libspa-v4l2
    audio.aec.*     = aec/libspa-aec
}

context.modules = [
    { name = libpipewire-module-rt
        args = {
            nice.level   = -11
            rt.prio      = 88
            rt.time.soft = -1
            rt.time.hard = -1
        }
        flags = [ nofail ]
    }
    { name = libpipewire-module-protocol-native }
    { name = libpipewire-module-profiler }
    { name = libpipewire-module-metadata }
    { name = libpipewire-module-spa-device-factory }
    { name = libpipewire-module-spa-node-factory }
    { name = libpipewire-module-client-node }
    { name = libpipewire-module-client-device }
    { name = libpipewire-module-adapter
        args = { }
    }
    { name = libpipewire-module-link-factory }
    { name = libpipewire-module-session-manager }
]

context.objects = [
    { factory = spa-node-factory
        args = {
            factory.name     = support.node.driver
            node.name        = Dummy-Driver
            node.group       = pipewire.dummy
            priority.driver  = 20000
        }
    }
    { factory = spa-node-factory
        args = {
            factory.name    = support.node.driver
            node.name       = Freewheel-Driver
            priority.driver = 19000
            node.group      = pipewire.freewheel
            node.freewheel  = true
        }
    }
    { factory = adapter
        args = {
            factory.name     = support.null-audio-sink
            node.name        = virtual_speaker
            node.description = "Virtual Marketing Speaker"
            media.class      = Audio/Sink
            audio.channels   = 2
            audio.position   = [ FL FR ]
            monitor.channel-volumes = true
        }
    }
    { factory = adapter
        args = {
            factory.name     = support.null-audio-sink
            node.name        = virtual_microphone
            node.description = "Virtual Marketing Microphone"
            media.class      = Audio/Sink
            audio.channels   = 2
            audio.position   = [ FL FR ]
        }
    }
]

context.exec = [
    { path = "pactl"
        args = "load-module module-always-sink"
        flags = [ nofail ]
    }
]
EOF

# Create user-specific PipeWire configuration (runtime only)
if [ "$IS_RUNTIME" = true ]; then
    mkdir -p "/home/${DEV_USERNAME}/.config/pipewire"
    cat <<EOF > "/home/${DEV_USERNAME}/.config/pipewire/pipewire.conf"
# User-specific PipeWire configuration
context.properties = {
    default.clock.rate        = 44100
    default.clock.quantum     = 1024
    link.max-buffers         = 64
    log.level                = 2
    core.daemon              = true
    core.name                = pipewire-${DEV_UID}
}

context.spa-libs = {
    audio.convert.* = audioconvert/libspa-audioconvert
    api.alsa.*      = alsa/libspa-alsa
    api.v4l2.*      = v4l2/libspa-v4l2
    support.*       = support/libspa-support
}

context.modules = [
    { name = libpipewire-module-rt }
    { name = libpipewire-module-protocol-native }
    { name = libpipewire-module-client-node }
    { name = libpipewire-module-adapter }
    { name = libpipewire-module-link-factory }
]
EOF

    # Set proper ownership (runtime only)
    chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/.config"
fi

# Create ALSA configuration for PipeWire compatibility
cat <<EOF > /etc/asound.conf
# ALSA configuration for PipeWire
pcm.!default {
    type pipewire
    playback_node virtual_speaker
    capture_node virtual_microphone.monitor
    hint {
        show on
        description "PipeWire Sound Server"
    }
}

ctl.!default {
    type pipewire
}

# Virtual marketing devices
pcm.marketing_speaker {
    type pipewire
    playback_node virtual_speaker
    hint {
        show on
        description "Virtual Marketing Speaker"
    }
}

pcm.marketing_microphone {
    type pipewire
    capture_node virtual_microphone.monitor
    hint {
        show on
        description "Virtual Marketing Microphone"
    }
}
EOF

# Create user-specific ALSA configuration (runtime only)
if [ "$IS_RUNTIME" = true ]; then
    cat <<EOF > "/home/${DEV_USERNAME}/.asoundrc"
# User ALSA configuration for PipeWire
pcm.!default {
    type pipewire
    playback_node virtual_speaker
    capture_node virtual_microphone.monitor
}

ctl.!default {
    type pipewire
}
EOF

    chown "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/.asoundrc"
fi

# Create PipeWire test script
cat <<'EOF' > /usr/local/bin/test-pipewire.sh
#!/bin/bash

# PipeWire Testing Script
set -e

echo "🔊 PipeWire System Testing..."

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

# Test PipeWire server connectivity
test_pipewire_connectivity() {
    echo "🔍 Testing PipeWire connectivity..."
    
    if pw-cli info >/dev/null 2>&1; then
        green "✅ PipeWire server is accessible"
    else
        red "❌ PipeWire server not accessible"
        return 1
    fi
    
    # Test WirePlumber
    if wpctl status >/dev/null 2>&1; then
        green "✅ WirePlumber session manager accessible"
    else
        yellow "⚠️  WirePlumber not accessible"
    fi
}

# Test audio devices
test_audio_devices() {
    echo "🔍 Testing audio devices..."
    
    echo "Available audio sinks:"
    if wpctl status | grep -A 10 "Audio"; then
        green "✅ Audio devices detected"
    else
        red "❌ No audio devices found"
    fi
    
    echo "PipeWire nodes:"
    if pw-cli list-objects | grep -E "(virtual_speaker|virtual_microphone)"; then
        green "✅ Virtual audio devices found"
    else
        yellow "⚠️  Virtual audio devices not found"
    fi
}

# Test audio generation capability
test_audio_generation() {
    echo "🔍 Testing audio generation..."
    
    # Test with gst-launch
    if command -v gst-launch-1.0 > /dev/null; then
        if timeout 3 gst-launch-1.0 audiotestsrc freq=440 ! audioconvert ! pipewiresink node-name=virtual_speaker >/dev/null 2>&1; then
            green "✅ GStreamer audio test successful"
        else
            yellow "⚠️  GStreamer audio test failed"
        fi
    else
        yellow "⚠️  GStreamer not available"
    fi
}

# Main test execution
main() {
    echo "$(date): Starting PipeWire system test"
    
    test_pipewire_connectivity || true
    test_audio_devices || true
    test_audio_generation || true
    
    echo ""
    blue "🎵 PipeWire system test completed!"
}

# Allow script to be sourced or executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF

chmod +x /usr/local/bin/test-pipewire.sh

echo "✅ PipeWire audio system setup complete"