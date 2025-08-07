#!/bin/bash
# Enhanced Audio Recovery Script for Ubuntu KDE WebTop
# Fixes PipeWire, WirePlumber, and virtual device issues
set -euo pipefail

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') [AudioRecovery] $*"
}

# Environment variables
DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"
XDG_RUNTIME_DIR="/run/user/${DEV_UID}"

log "🚀 Starting Enhanced Audio Recovery for Ubuntu KDE WebTop"

# Phase 1: Fix Core Environment
fix_core_environment() {
    log "🔧 Phase 1: Fixing core environment..."
    
    # Ensure user exists
    if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
        red "❌ User $DEV_USERNAME does not exist"
        return 1
    fi
    
    # Create and fix runtime directories
    mkdir -p "$XDG_RUNTIME_DIR/pipewire"
    chown -R "$DEV_USERNAME:$DEV_USERNAME" "$XDG_RUNTIME_DIR" 2>/dev/null || true
    chmod 700 "$XDG_RUNTIME_DIR"
    
    # Add user to audio group
    usermod -a -G audio "$DEV_USERNAME" 2>/dev/null || true
    
    # Fix audio device permissions
    if [ -d "/dev/snd" ]; then
        chown -R root:audio /dev/snd
        chmod -R g+rw /dev/snd
    fi
    
    green "✅ Core environment fixed"
}

# Phase 2: Stop and Clean Audio Services
stop_audio_services() {
    log "🛑 Phase 2: Stopping existing audio services..."
    
    # Stop supervisor audio services
    supervisorctl stop audio:* 2>/dev/null || true
    supervisorctl stop pipewire 2>/dev/null || true
    supervisorctl stop wireplumber 2>/dev/null || true
    supervisorctl stop create-virtual-devices 2>/dev/null || true
    
    # Kill any remaining processes
    pkill -f pipewire || true
    pkill -f wireplumber || true
    pkill -f pw-cli || true
    
    # Clean up stale sockets
    rm -f "$XDG_RUNTIME_DIR"/pipewire-* 2>/dev/null || true
    rm -f "$XDG_RUNTIME_DIR"/pulse-* 2>/dev/null || true
    
    sleep 3
    green "✅ Audio services stopped and cleaned"
}

# Phase 3: Start PipeWire with proper configuration
start_pipewire() {
    log "🎵 Phase 3: Starting PipeWire daemon..."
    
    # Start PipeWire as user with proper environment
    su - "$DEV_USERNAME" -c "
        export XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR'
        export DBUS_SESSION_BUS_ADDRESS='unix:path=$XDG_RUNTIME_DIR/bus'
        /usr/bin/pipewire &
    "
    
    # Wait for PipeWire to be ready
    local retries=15
    while [ $retries -gt 0 ]; do
        if su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR'; pw-cli info" >/dev/null 2>&1; then
            green "✅ PipeWire started successfully"
            return 0
        fi
        sleep 2
        retries=$((retries - 1))
    done
    
    red "❌ PipeWire failed to start"
    return 1
}

# Phase 4: Start WirePlumber
start_wireplumber() {
    log "🔌 Phase 4: Starting WirePlumber session manager..."
    
    # Start WirePlumber as user
    su - "$DEV_USERNAME" -c "
        export XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR'
        export DBUS_SESSION_BUS_ADDRESS='unix:path=$XDG_RUNTIME_DIR/bus'
        /usr/bin/wireplumber &
    "
    
    # Wait for WirePlumber to be ready
    local retries=10
    while [ $retries -gt 0 ]; do
        if su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR'; wpctl status" >/dev/null 2>&1; then
            green "✅ WirePlumber started successfully"
            return 0
        fi
        sleep 2
        retries=$((retries - 1))
    done
    
    yellow "⚠️  WirePlumber may not be fully ready, continuing..."
    return 0
}

# Phase 5: Create Virtual Devices
create_virtual_devices() {
    log "🎧 Phase 5: Creating virtual audio devices..."
    
    # Use the enhanced virtual device creation script
    if /usr/local/bin/create-virtual-pipewire-devices.sh; then
        green "✅ Virtual devices created successfully"
        return 0
    else
        yellow "⚠️  Virtual device creation had issues, trying manual approach..."
        
        # Manual device creation fallback
        su - "$DEV_USERNAME" -c "
            export XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR'
            pw-cli create-node adapter factory.name=support.null-audio-sink node.name=virtual_speaker node.description='Virtual Marketing Speaker' media.class=Audio/Sink audio.channels=2
            pw-cli create-node adapter factory.name=support.null-audio-sink node.name=virtual_microphone node.description='Virtual Marketing Microphone' media.class=Audio/Sink audio.channels=2
        " || yellow "⚠️  Manual device creation also failed"
        
        return 0
    fi
}

# Phase 6: Restart Supervisor Audio Services
restart_supervisor_audio() {
    log "🔄 Phase 6: Restarting supervisor audio services..."
    
    # Restart the audio group
    supervisorctl start audio:* 2>/dev/null || true
    
    # Check if services are running
    sleep 5
    if supervisorctl status pipewire | grep -q "RUNNING"; then
        green "✅ Supervisor PipeWire service running"
    else
        yellow "⚠️  Supervisor PipeWire service not running (manual process may be active)"
    fi
    
    if supervisorctl status wireplumber | grep -q "RUNNING"; then
        green "✅ Supervisor WirePlumber service running"  
    else
        yellow "⚠️  Supervisor WirePlumber service not running (manual process may be active)"
    fi
}

# Phase 7: Test Audio System
test_audio_system() {
    log "🧪 Phase 7: Testing audio system..."
    
    # Test PipeWire connectivity
    if su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR'; pw-cli info" >/dev/null 2>&1; then
        green "✅ PipeWire connectivity test passed"
    else
        red "❌ PipeWire connectivity test failed"
        return 1
    fi
    
    # Test WirePlumber
    if su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR'; wpctl status" >/dev/null 2>&1; then
        green "✅ WirePlumber test passed"
    else
        yellow "⚠️  WirePlumber test failed"
    fi
    
    # Check for virtual devices
    if su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR'; pw-cli list-objects | grep -E '(virtual_speaker|virtual_microphone)'" >/dev/null 2>&1; then
        green "✅ Virtual devices found"
    else
        yellow "⚠️  Virtual devices not found"
    fi
    
    # Test WebRTC bridge
    if curl -sf http://localhost:8080/package.json >/dev/null 2>&1; then
        green "✅ WebRTC bridge responding"
    else
        yellow "⚠️  WebRTC bridge not responding"
    fi
}

# Phase 8: Display Status Report
display_status_report() {
    log "📊 Phase 8: Audio System Status Report"
    
    echo ""
    blue "=== AUDIO SYSTEM STATUS REPORT ==="
    echo ""
    
    # PipeWire Status
    if su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR'; pw-cli info" >/dev/null 2>&1; then
        green "✅ PipeWire: Running"
    else
        red "❌ PipeWire: Not Running"
    fi
    
    # WirePlumber Status  
    if su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR'; wpctl status" >/dev/null 2>&1; then
        green "✅ WirePlumber: Running"
    else
        red "❌ WirePlumber: Not Running"
    fi
    
    # Virtual Devices
    local device_count
    device_count=$(su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR'; pw-cli list-objects | grep -E '(virtual_speaker|virtual_microphone)' | wc -l" 2>/dev/null || echo "0")
    if [ "$device_count" -gt 0 ]; then
        green "✅ Virtual Devices: $device_count devices found"
    else
        red "❌ Virtual Devices: None found"
    fi
    
    # WebRTC Bridge
    if curl -sf http://localhost:8080/package.json >/dev/null 2>&1; then
        green "✅ WebRTC Bridge: Responding on port 8080"
    else
        red "❌ WebRTC Bridge: Not responding"
    fi
    
    echo ""
    blue "=== NEXT STEPS ==="
    echo "1. Access noVNC desktop via your container's exposed port"
    echo "2. Test audio in applications within the desktop"
    echo "3. Use WebRTC audio controls if available"
    echo "4. Monitor logs: supervisorctl logs pipewire"
    echo ""
}

# Main execution
main() {
    log "Starting comprehensive audio system recovery..."
    
    # Execute all phases
    if fix_core_environment && \
       stop_audio_services && \
       start_pipewire && \
       start_wireplumber && \
       create_virtual_devices; then
        
        restart_supervisor_audio
        test_audio_system
        display_status_report
        
        green "🎉 Audio system recovery completed!"
        exit 0
    else
        red "❌ Audio system recovery failed at one or more phases"
        display_status_report
        exit 1
    fi
}

# Allow script to be sourced or executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi