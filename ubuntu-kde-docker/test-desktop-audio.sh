#!/bin/bash

# Desktop Audio Integration Test Script
# Tests audio functionality in KDE Plasma with remote access scenarios

# Configuration
DEV_USERNAME=${DEV_USERNAME:-devuser}
DISPLAY=${DISPLAY:-:1}

# Color output functions
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }

# Test KDE audio integration
test_kde_audio() {
    echo "$(blue '🔊 Testing KDE Plasma Audio Integration...')"
    
    if pgrep -f "startplasma\|plasmashell" > /dev/null; then
        green "✅ KDE Plasma is running"
        
        # Test KDE system sounds
        if command -v knotify5 > /dev/null 2>&1; then
            green "✅ KNotify5 available for system sounds"
        else
            yellow "⚠️  KNotify5 not found - system sounds may not work"
        fi
        
        # Check for KDE audio settings
        if [ -f "/usr/bin/systemsettings5" ]; then
            green "✅ KDE System Settings available"
        else
            yellow "⚠️  KDE System Settings not found"
        fi
    else
        red "❌ KDE Plasma is not running"
        return 1
    fi
}

# Test media applications
test_media_applications() {
    echo "$(blue '🎵 Testing Media Applications...')"
    
    local apps=("firefox" "vlc" "audacity" "aplay" "arecord" "pactl")
    
    for app in "${apps[@]}"; do
        if command -v "$app" > /dev/null 2>&1; then
            green "✅ $app is available"
        else
            yellow "⚠️  $app not found"
        fi
    done
    
    # Test basic audio utilities
    if command -v speaker-test > /dev/null 2>&1; then
        green "✅ speaker-test available for audio testing"
    else
        yellow "⚠️  speaker-test not available"
    fi
}

# Test audio development tools
test_audio_dev_tools() {
    echo "$(blue '🛠️  Testing Audio Development Tools...')"
    
    # Check development tools
    local dev_tools=("python3" "node" "gcc" "make")
    for tool in "${dev_tools[@]}"; do
        if command -v "$tool" > /dev/null 2>&1; then
            green "✅ $tool is available"
        else
            yellow "⚠️  $tool not found"
        fi
    done
    
    # Check Python audio libraries
    if python3 -c "import sounddevice" 2>/dev/null; then
        green "✅ Python sounddevice library available"
    else
        yellow "⚠️  Python sounddevice library not found"
    fi
    
    if python3 -c "import pyaudio" 2>/dev/null; then
        green "✅ Python pyaudio library available"
    else
        yellow "⚠️  Python pyaudio library not found"
    fi
}

# Test remote audio forwarding
test_remote_audio_forwarding() {
    echo "$(blue '📡 Testing Remote Audio Forwarding...')"
    
    # Test VNC audio forwarding
    if pgrep -f "x11vnc" > /dev/null; then
        green "✅ VNC server is running"
        
        if netstat -tuln 2>/dev/null | grep -q ":5901 "; then
            green "✅ VNC port 5901 is listening"
        else
            yellow "⚠️  VNC port 5901 not listening"
        fi
    else
        red "❌ VNC server not running"
    fi
    
    
    # Test PulseAudio network capability
    if pgrep -f "pulseaudio" > /dev/null; then
        green "✅ PulseAudio daemon is running"
        
        if pactl info > /dev/null 2>&1; then
            green "✅ PulseAudio is responding to commands"
        else
            yellow "⚠️  PulseAudio not responding"
        fi
    else
        red "❌ PulseAudio daemon not running"
    fi
}

# Create demo audio application
create_demo_audio_app() {
    echo "$(blue '🎯 Creating Demo Audio Application...')"
    
    cat > /tmp/audio_demo.py << 'EOF'
#!/usr/bin/env python3

import sys
import subprocess
import time

def test_audio_output():
    """Test audio output using pactl"""
    print("🔊 Testing audio output...")
    
    try:
        # Get PulseAudio info
        result = subprocess.run(['pactl', 'info'], capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print("✅ PulseAudio is responding")
            print(f"Server info: {result.stdout.split('Server Name:')[1].split()[0] if 'Server Name:' in result.stdout else 'Unknown'}")
        else:
            print("❌ PulseAudio not responding")
            return False
    except Exception as e:
        print(f"❌ Error accessing PulseAudio: {e}")
        return False
    
    # List sinks
    try:
        result = subprocess.run(['pactl', 'list', 'short', 'sinks'], capture_output=True, text=True, timeout=10)
        if result.returncode == 0 and result.stdout.strip():
            print("✅ Audio sinks available:")
            for line in result.stdout.strip().split('\n'):
                print(f"   - {line}")
        else:
            print("❌ No audio sinks found")
            return False
    except Exception as e:
        print(f"❌ Error listing sinks: {e}")
        return False
    
    return True

def test_audio_input():
    """Test audio input detection"""
    print("🎤 Testing audio input...")
    
    try:
        result = subprocess.run(['pactl', 'list', 'short', 'sources'], capture_output=True, text=True, timeout=10)
        if result.returncode == 0 and result.stdout.strip():
            print("✅ Audio sources available:")
            for line in result.stdout.strip().split('\n'):
                if 'monitor' not in line.lower():
                    print(f"   - {line}")
        else:
            print("⚠️  No audio input sources found")
    except Exception as e:
        print(f"❌ Error listing sources: {e}")

def main():
    print("🎵 Desktop Audio Integration Demo")
    print("=" * 40)
    
    # Test output
    if test_audio_output():
        print("✅ Audio output test passed")
    else:
        print("❌ Audio output test failed")
        sys.exit(1)
    
    # Test input
    test_audio_input()
    
    print("=" * 40)
    print("🎉 Audio demo completed successfully!")

if __name__ == "__main__":
    main()
EOF
    
    chmod +x /tmp/audio_demo.py
    green "✅ Demo audio application created at /tmp/audio_demo.py"
}

# Generate integration report
generate_integration_report() {
    echo "$(blue '📋 Desktop Audio Integration Report')"
    echo "=" * 50
    
    # Environment info
    echo "🖥️  Environment:"
    echo "   Display: $DISPLAY"
    echo "   User: $DEV_USERNAME"
    echo "   Date: $(date)"
    echo ""
    
    # PulseAudio status
    echo "🔊 PulseAudio Configuration:"
    if pgrep -f "pulseaudio" > /dev/null; then
        echo "   Status: RUNNING"
        if pactl info > /dev/null 2>&1; then
            local server_name=$(pactl info 2>/dev/null | grep "Server Name:" | cut -d: -f2 | xargs)
            echo "   Server: ${server_name:-Unknown}"
        fi
    else
        echo "   Status: NOT RUNNING"
    fi
    echo ""
    
    # Audio devices
    echo "🎵 Audio Devices:"
    if command -v pactl > /dev/null 2>&1; then
        local sink_count=$(pactl list short sinks 2>/dev/null | wc -l)
        local source_count=$(pactl list short sources 2>/dev/null | wc -l)
        echo "   Output devices: $sink_count"
        echo "   Input devices: $source_count"
    else
        echo "   pactl not available"
    fi
    echo ""
    
    # KDE status
    echo "🖥️  KDE Plasma:"
    if pgrep -f "startplasma\|plasmashell" > /dev/null; then
        echo "   Status: RUNNING"
    else
        echo "   Status: NOT RUNNING"
    fi
    echo ""
    
    # Remote access
    echo "📡 Remote Access:"
    echo "   VNC (port 5901): $(netstat -tuln 2>/dev/null | grep -q ":5901 " && echo "LISTENING" || echo "NOT LISTENING")"
    echo "   noVNC (port 80): $(netstat -tuln 2>/dev/null | grep -q ":80 " && echo "LISTENING" || echo "NOT LISTENING")"
    
    echo "=" * 50
}

# Main function
main() {
    echo "$(green '🎵 Desktop Audio Integration Testing')"
    echo "=" * 50
    
    test_kde_audio
    echo ""
    
    test_media_applications
    echo ""
    
    test_audio_dev_tools
    echo ""
    
    test_remote_audio_forwarding
    echo ""
    
    create_demo_audio_app
    echo ""
    
    generate_integration_report
    
    # Run demo if requested
    if [ "$1" = "--run-demo" ]; then
        echo ""
        echo "$(blue '🚀 Running audio demo application...')"
        python3 /tmp/audio_demo.py
    fi
}

# Execute main function
main "$@"