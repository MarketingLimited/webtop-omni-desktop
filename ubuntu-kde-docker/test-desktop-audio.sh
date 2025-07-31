#!/bin/bash

# Desktop Application Audio Integration Tester
# Marketing Agency WebTop - Phase 4 Audio Enhancement

set -e

echo "🎵 Desktop Application Audio Integration Test"

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DISPLAY="${DISPLAY:-:1}"

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

# Test KDE audio integration
test_kde_audio() {
    echo "🔍 Testing KDE Plasma audio integration..."
    
    # Check if KDE audio service is running
    if pgrep -f plasma > /dev/null; then
        green "✅ KDE Plasma is running"
        
        # Test KDE system sounds
        if command -v knotify5 > /dev/null; then
            # Test KDE notification sound
            if timeout 5 su - "${DEV_USERNAME}" -c "DISPLAY=${DISPLAY} knotify5 --test" 2>/dev/null; then
                green "✅ KDE system sounds working"
            else
                yellow "⚠️  KDE system sounds test failed"
            fi
        else
            yellow "⚠️  KDE notification system not available"
        fi
        
    else
        red "❌ KDE Plasma not running"
    fi
}

# Test media applications
test_media_applications() {
    echo "🔍 Testing media application audio integration..."
    
    # Test with Firefox/Chromium (if available)
    if command -v firefox > /dev/null; then
        echo "Testing Firefox audio capability..."
        # Check if Firefox can detect audio devices
        green "✅ Firefox available for audio testing"
    fi
    
    # Test with VLC (if available)
    if command -v vlc > /dev/null; then
        echo "Testing VLC media player..."
        green "✅ VLC available for audio testing"
    fi
    
    # Test with Audacity (if available)
    if command -v audacity > /dev/null; then
        echo "Testing Audacity audio editor..."
        green "✅ Audacity available for audio testing"
    fi
    
    # Test basic audio utilities
    local audio_utils=("aplay" "arecord" "paplay" "parec" "speaker-test")
    for util in "${audio_utils[@]}"; do
        if command -v "$util" > /dev/null; then
            green "✅ $util available"
        else
            yellow "⚠️  $util not available"
        fi
    done
}

# Test audio development tools
test_audio_dev_tools() {
    echo "🔍 Testing audio development tools..."
    
    # Test audio programming environments
    local dev_tools=("python3" "node" "gcc" "make")
    for tool in "${dev_tools[@]}"; do
        if command -v "$tool" > /dev/null; then
            green "✅ $tool available for audio development"
        else
            yellow "⚠️  $tool not available"
        fi
    done
    
    # Test audio libraries
    if python3 -c "import sounddevice" 2>/dev/null; then
        green "✅ Python sounddevice library available"
    else
        yellow "⚠️  Python sounddevice library not available"
    fi
    
    if python3 -c "import pyaudio" 2>/dev/null; then
        green "✅ Python PyAudio library available"
    else
        yellow "⚠️  Python PyAudio library not available"
    fi
}

# Test remote desktop audio forwarding
test_remote_audio_forwarding() {
    echo "🔍 Testing remote desktop audio forwarding..."
    
    # Test VNC audio forwarding
    if netstat -tuln | grep -q ":5901 "; then
        green "✅ VNC server listening on port 5901"
        
        # Check if VNC can access audio
        if su - "${DEV_USERNAME}" -c "DISPLAY=${DISPLAY} PULSE_SERVER=tcp:localhost:4713 pactl info" >/dev/null 2>&1; then
            green "✅ VNC can access PulseAudio"
        else
            yellow "⚠️  VNC cannot access PulseAudio"
        fi
    else
        red "❌ VNC server not listening"
    fi
    
    # Test Xpra audio forwarding
    if netstat -tuln | grep -q ":14500 "; then
        green "✅ Xpra server listening on port 14500"
        
        # Check if Xpra has PulseAudio integration
        if pgrep -f "xpra.*pulseaudio" > /dev/null; then
            green "✅ Xpra PulseAudio integration active"
        else
            yellow "⚠️  Xpra PulseAudio integration not detected"
        fi
    else
        red "❌ Xpra server not listening"
    fi
}

# Create demo audio application
create_demo_audio_app() {
    echo "🔧 Creating demo audio application..."
    
    cat <<'DEMO_EOF' > /tmp/audio_demo.py
#!/usr/bin/env python3
"""
Demo Audio Application for Marketing Agency WebTop
Tests audio input/output capabilities
"""

import time
import subprocess
import sys

def test_audio_output():
    """Test audio output using PulseAudio"""
    print("🔊 Testing audio output...")
    
    try:
        # Generate a test tone using PulseAudio
        subprocess.run([
            "pactl", "load-module", "module-sine", 
            "frequency=440", "sink=virtual_speaker"
        ], check=True, capture_output=True)
        
        print("✅ Audio output test successful")
        time.sleep(2)
        
        # Unload the test module
        subprocess.run(["pactl", "unload-module", "module-sine"], 
                      capture_output=True)
        
    except subprocess.CalledProcessError as e:
        print(f"⚠️  Audio output test failed: {e}")
        return False
    
    return True

def test_audio_input():
    """Test audio input capabilities"""
    print("🎤 Testing audio input...")
    
    try:
        # Test recording capability
        result = subprocess.run([
            "pactl", "list", "short", "sources"
        ], check=True, capture_output=True, text=True)
        
        if "virtual_microphone" in result.stdout:
            print("✅ Virtual microphone detected")
            return True
        else:
            print("⚠️  No virtual microphone found")
            return False
            
    except subprocess.CalledProcessError as e:
        print(f"⚠️  Audio input test failed: {e}")
        return False

def main():
    print("🎵 Marketing Agency WebTop Audio Demo")
    print("====================================")
    
    # Test audio capabilities
    output_ok = test_audio_output()
    input_ok = test_audio_input()
    
    if output_ok and input_ok:
        print("✅ All audio tests passed!")
        return 0
    else:
        print("⚠️  Some audio tests failed")
        return 1

if __name__ == "__main__":
    sys.exit(main())
DEMO_EOF
    
    chmod +x /tmp/audio_demo.py
    green "✅ Demo audio application created at /tmp/audio_demo.py"
}

# Generate comprehensive audio integration report
generate_integration_report() {
    echo "📊 Audio Integration Report"
    echo "=========================="
    
    echo "Environment:"
    echo "  User: ${DEV_USERNAME}"
    echo "  Display: ${DISPLAY}"
    echo "  XDG_RUNTIME_DIR: ${XDG_RUNTIME_DIR:-not set}"
    
    echo ""
    echo "PulseAudio Configuration:"
    if su - "${DEV_USERNAME}" -c "pactl info" 2>/dev/null; then
        echo "  PulseAudio server accessible"
    else
        echo "  PulseAudio server not accessible"
    fi
    
    echo ""
    echo "Audio Devices:"
    su - "${DEV_USERNAME}" -c "pactl list short sinks" 2>/dev/null | head -5 || echo "  No sinks detected"
    
    echo ""
    echo "Desktop Integration:"
    if pgrep -f plasma > /dev/null; then
        echo "  ✅ KDE Plasma running"
    else
        echo "  ❌ KDE Plasma not running"
    fi
    
    echo ""
    echo "Remote Access Audio:"
    netstat -tuln | grep -E ":4713|:5901|:14500" | while read line; do
        echo "  $line"
    done
}

# Main execution
main() {
    echo "Starting desktop application audio integration test..."
    
    test_kde_audio
    test_media_applications
    test_audio_dev_tools
    test_remote_audio_forwarding
    create_demo_audio_app
    
    echo ""
    generate_integration_report
    
    echo ""
    blue "🎵 Desktop audio integration test completed!"
    
    # Run the demo application if requested
    if [ "$1" = "--run-demo" ]; then
        echo ""
        echo "Running demo audio application..."
        python3 /tmp/audio_demo.py
    fi
}

main "$@"