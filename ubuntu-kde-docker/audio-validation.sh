#!/bin/bash
# Audio System Validation Script for Marketing Agency WebTop
# Validates and repairs audio configuration after container startup

set -e

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"

echo "🔊 Validating audio system configuration..."

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

# Check if PulseAudio is running with virtual devices
validate_pulseaudio() {
    echo "🔍 Validating PulseAudio configuration..."
    
    # Wait for PulseAudio to start
    timeout=30
    while [ $timeout -gt 0 ]; do
        if pactl info >/dev/null 2>&1; then
            break
        fi
        sleep 1
        timeout=$((timeout - 1))
    done
    
    if ! pactl info >/dev/null 2>&1; then
        red "❌ PulseAudio not responding after 30 seconds"
        return 1
    fi
    
    # Check for virtual devices
    if pactl list short sinks | grep -q "virtual_speaker"; then
        green "✅ Virtual speaker device found"
    else
        yellow "⚠️  Virtual speaker device missing, attempting to create..."
        pactl load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description="Virtual_Marketing_Speaker" || true
    fi
    
    if pactl list short sources | grep -q "virtual_mic_source\|virtual_microphone.monitor"; then
        green "✅ Virtual microphone source found"
    else
        yellow "⚠️  Virtual microphone source missing, attempting to create..."
        pactl load-module module-null-sink sink_name=virtual_microphone sink_properties=device.description="Virtual_Marketing_Microphone" || true
    fi
    
    # Set defaults if not already set
    current_sink=$(pactl get-default-sink 2>/dev/null || echo "")
    if [ "$current_sink" != "virtual_speaker" ]; then
        pactl set-default-sink virtual_speaker 2>/dev/null || yellow "⚠️  Could not set default sink"
    fi
    
    return 0
}

# Test audio device visibility in KDE
test_kde_audio_integration() {
    echo "🔍 Testing KDE audio integration..."
    
    # Check if KDE can see audio devices
    if command -v qdbus >/dev/null 2>&1; then
        # Try to query KDE audio system
        if qdbus org.kde.kded5 /modules/kmix 2>/dev/null; then
            green "✅ KDE audio system responding"
        else
            yellow "⚠️  KDE audio system not responding"
        fi
    fi
    
    # Check if audio volume applet can find devices
    export DISPLAY=:1
    if command -v pactl >/dev/null && pactl list short sinks | grep -q virtual; then
        green "✅ Virtual audio devices available for KDE"
    else
        yellow "⚠️  Audio devices may not be visible in KDE"
    fi
}

# Create desktop audio test file
create_audio_test_script() {
    echo "🔧 Creating desktop audio test script..."
    
    cat <<'SCRIPT_EOF' > "/home/${DEV_USERNAME}/test-audio.sh"
#!/bin/bash
# Desktop Audio Test Script

echo "🎵 Testing audio system from desktop..."

# Test PulseAudio connectivity
echo "Testing PulseAudio connection..."
if pactl info; then
    echo "✅ PulseAudio connection successful"
else
    echo "❌ PulseAudio connection failed"
    exit 1
fi

# List available devices
echo ""
echo "Available audio sinks:"
pactl list short sinks

echo ""
echo "Available audio sources:"
pactl list short sources

# Test audio generation
echo ""
echo "Testing audio generation (3 seconds of tone)..."
if command -v speaker-test >/dev/null; then
    speaker-test -t sine -f 440 -l 1 -s 1 &
    SPEAKER_PID=$!
    sleep 3
    kill $SPEAKER_PID 2>/dev/null || true
    echo "✅ Audio test completed"
else
    echo "⚠️  speaker-test not available"
fi

echo ""
echo "🎵 Audio test completed! Check the KDE audio settings panel."
SCRIPT_EOF

    chown "${DEV_USERNAME}:${DEV_USERNAME}" "/home/${DEV_USERNAME}/test-audio.sh"
    chmod +x "/home/${DEV_USERNAME}/test-audio.sh"
    
    green "✅ Audio test script created at /home/${DEV_USERNAME}/test-audio.sh"
}

# Main validation function
main() {
    echo "Starting audio system validation..."
    
    # Wait a moment for services to settle
    sleep 5
    
    validate_pulseaudio
    test_kde_audio_integration  
    create_audio_test_script
    
    echo ""
    blue "🎵 Audio validation completed!"
    echo ""
    echo "To test audio in the desktop:"
    echo "1. Open KDE System Settings > Audio"
    echo "2. Check if Virtual_Marketing_Speaker and Virtual_Marketing_Microphone are visible"
    echo "3. Run: /home/${DEV_USERNAME}/test-audio.sh from a terminal"
    echo ""
    
    # Final device count
    device_count=$(pactl list short sinks | wc -l)
    if [ "$device_count" -gt 0 ]; then
        green "✅ Audio validation successful! Found $device_count audio devices."
    else
        red "❌ Audio validation failed! No audio devices found."
        return 1
    fi
}

# Run validation if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi