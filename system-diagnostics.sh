#!/bin/bash
# System Diagnostics Script
# Comprehensive diagnostic tool for troubleshooting WebTop issues

set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-$(id -u "$DEV_USERNAME" 2>/dev/null || echo 1000)}"
DIAGNOSTIC_LOG="/tmp/system-diagnostics-$(date +%Y%m%d-%H%M%S).log"

# Color output functions
red() { echo -e "\033[31m$*\033[0m"; }
green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
blue() { echo -e "\033[34m$*\033[0m"; }
bold() { echo -e "\033[1m$*\033[0m"; }

# Logging function
log_diagnostic() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DIAGNOSTIC] $*" | tee -a "$DIAGNOSTIC_LOG"
}

# Header function
print_header() {
    local title="$1"
    echo ""
    bold "================================================================================"
    bold "$title"
    bold "================================================================================"
    echo ""
}

# System information
collect_system_info() {
    print_header "SYSTEM INFORMATION"
    
    log_diagnostic "Hostname: $(hostname)"
    log_diagnostic "Uptime: $(uptime)"
    log_diagnostic "Kernel: $(uname -a)"
    log_diagnostic "Distribution: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"' || echo 'Unknown')"
    log_diagnostic "Memory: $(free -h 2>/dev/null | grep Mem || echo 'Memory info unavailable')"
    log_diagnostic "Disk: $(df -h / 2>/dev/null || echo 'Disk info unavailable')"
    log_diagnostic "Load Average: $(cat /proc/loadavg 2>/dev/null || echo 'Load average unavailable')"
}

# User information
collect_user_info() {
    print_header "USER INFORMATION"
    
    log_diagnostic "Current user: $(whoami)"
    log_diagnostic "User ID: $(id)"
    
    if id "$DEV_USERNAME" >/dev/null 2>&1; then
        log_diagnostic "Dev user exists: $DEV_USERNAME (UID: $DEV_UID)"
        log_diagnostic "Dev user groups: $(groups "$DEV_USERNAME" 2>/dev/null || echo 'Groups unavailable')"
        log_diagnostic "Dev user home: $(eval echo ~"$DEV_USERNAME")"
        log_diagnostic "XDG_RUNTIME_DIR: /run/user/$DEV_UID"
        log_diagnostic "Runtime dir exists: $([ -d "/run/user/$DEV_UID" ] && echo 'Yes' || echo 'No')"
        log_diagnostic "Runtime dir permissions: $(ls -ld "/run/user/$DEV_UID" 2>/dev/null || echo 'Not accessible')"
    else
        log_diagnostic "Dev user does not exist: $DEV_USERNAME"
    fi
}

# Process information
collect_process_info() {
    print_header "PROCESS INFORMATION"
    
    log_diagnostic "Supervisor processes:"
    pgrep -f supervisord >/dev/null && log_diagnostic "  supervisord: RUNNING (PID: $(pgrep -f supervisord))" || log_diagnostic "  supervisord: NOT RUNNING"
    
    log_diagnostic "Core processes:"
    pgrep -f "Xvfb.*:1" >/dev/null && log_diagnostic "  Xvfb: RUNNING (PID: $(pgrep -f "Xvfb.*:1"))" || log_diagnostic "  Xvfb: NOT RUNNING"
    pgrep -f "dbus.*system" >/dev/null && log_diagnostic "  D-Bus: RUNNING (PID: $(pgrep -f "dbus.*system"))" || log_diagnostic "  D-Bus: NOT RUNNING"
    
    log_diagnostic "Desktop processes:"
    pgrep -f "startplasma\|plasmashell" >/dev/null && log_diagnostic "  KDE: RUNNING (PIDs: $(pgrep -f "startplasma\|plasmashell" | tr '\n' ' '))" || log_diagnostic "  KDE: NOT RUNNING"
    
    log_diagnostic "Audio processes:"
    pgrep -f "pipewire" >/dev/null && log_diagnostic "  PipeWire: RUNNING (PIDs: $(pgrep -f "pipewire" | tr '\n' ' '))" || log_diagnostic "  PipeWire: NOT RUNNING"
    pgrep -f "wireplumber" >/dev/null && log_diagnostic "  WirePlumber: RUNNING (PIDs: $(pgrep -f "wireplumber" | tr '\n' ' '))" || log_diagnostic "  WirePlumber: NOT RUNNING"
    
    log_diagnostic "Remote access processes:"
    pgrep -f "x11vnc.*:1" >/dev/null && log_diagnostic "  X11VNC: RUNNING (PID: $(pgrep -f "x11vnc.*:1"))" || log_diagnostic "  X11VNC: NOT RUNNING"
    pgrep -f "websockify.*80.*:5901" >/dev/null && log_diagnostic "  noVNC: RUNNING (PID: $(pgrep -f "websockify.*80.*:5901"))" || log_diagnostic "  noVNC: NOT RUNNING"
    pgrep -f "ttyd.*7681" >/dev/null && log_diagnostic "  TTYD: RUNNING (PID: $(pgrep -f "ttyd.*7681"))" || log_diagnostic "  TTYD: NOT RUNNING"
    pgrep -f "sshd.*daemon" >/dev/null && log_diagnostic "  SSH: RUNNING (PID: $(pgrep -f "sshd.*daemon"))" || log_diagnostic "  SSH: NOT RUNNING"
}

# Network information
collect_network_info() {
    print_header "NETWORK INFORMATION"
    
    log_diagnostic "Network interfaces:"
    ip addr show 2>/dev/null | grep -E "^[0-9]+:|inet " | while read -r line; do
        log_diagnostic "  $line"
    done
    
    log_diagnostic "Listening ports:"
    netstat -tuln 2>/dev/null | grep LISTEN | while read -r line; do
        log_diagnostic "  $line"
    done
    
    log_diagnostic "Port status check:"
    local ports=("80:noVNC" "5901:VNC" "7681:TTYD" "22:SSH" "8080:WebRTC")
    for port_info in "${ports[@]}"; do
        local port="${port_info%%:*}"
        local service="${port_info##*:}"
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            log_diagnostic "  Port $port ($service): LISTENING"
        else
            log_diagnostic "  Port $port ($service): NOT LISTENING"
        fi
    done
}

# Audio system diagnostics
collect_audio_info() {
    print_header "AUDIO SYSTEM DIAGNOSTICS"
    
    if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
        log_diagnostic "Cannot check audio - dev user does not exist"
        return
    fi
    
    # PipeWire connectivity
    if su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR=/run/user/$DEV_UID; pw-cli info" >/dev/null 2>&1; then
        log_diagnostic "PipeWire connectivity: OK"
        
        # Get PipeWire info
        log_diagnostic "PipeWire server info:"
        su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR=/run/user/$DEV_UID; pw-cli info" 2>/dev/null | head -10 | while read -r line; do
            log_diagnostic "  $line"
        done
        
        # List audio nodes
        log_diagnostic "PipeWire audio nodes:"
        su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR=/run/user/$DEV_UID; pw-cli list-objects" 2>/dev/null | grep -E "(virtual_speaker|virtual_microphone|Audio/)" | while read -r line; do
            log_diagnostic "  $line"
        done
    else
        log_diagnostic "PipeWire connectivity: FAILED"
    fi
    
    # WirePlumber connectivity
    if su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR=/run/user/$DEV_UID; wpctl status" >/dev/null 2>&1; then
        log_diagnostic "WirePlumber connectivity: OK"
        
        # Get WirePlumber status
        log_diagnostic "WirePlumber status:"
        su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR=/run/user/$DEV_UID; wpctl status" 2>/dev/null | head -20 | while read -r line; do
            log_diagnostic "  $line"
        done
    else
        log_diagnostic "WirePlumber connectivity: FAILED"
    fi
    
    # Check audio files and directories
    log_diagnostic "Audio configuration files:"
    [ -f "/etc/asound.conf" ] && log_diagnostic "  /etc/asound.conf: EXISTS" || log_diagnostic "  /etc/asound.conf: MISSING"
    [ -f "/home/$DEV_USERNAME/.asoundrc" ] && log_diagnostic "  ~/.asoundrc: EXISTS" || log_diagnostic "  ~/.asoundrc: MISSING"
    [ -d "/home/$DEV_USERNAME/.config/pipewire" ] && log_diagnostic "  ~/.config/pipewire: EXISTS" || log_diagnostic "  ~/.config/pipewire: MISSING"
    [ -d "/home/$DEV_USERNAME/.config/wireplumber" ] && log_diagnostic "  ~/.config/wireplumber: EXISTS" || log_diagnostic "  ~/.config/wireplumber: MISSING"
}

# File system diagnostics
collect_filesystem_info() {
    print_header "FILE SYSTEM DIAGNOSTICS"
    
    log_diagnostic "Important directories:"
    local dirs=("/var/log/supervisor" "/tmp" "/run/user/$DEV_UID" "/home/$DEV_USERNAME")
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_diagnostic "  $dir: EXISTS ($(ls -ld "$dir" 2>/dev/null | awk '{print $1, $3, $4}'))"
        else
            log_diagnostic "  $dir: MISSING"
        fi
    done
    
    log_diagnostic "Log files:"
    local logs=("/var/log/supervisor/supervisord.log" "/var/log/supervisor/pipewire.log" "/var/log/supervisor/wireplumber.log" "/var/log/supervisor/audio-validation.log")
    for log_file in "${logs[@]}"; do
        if [ -f "$log_file" ]; then
            local size=$(stat -c%s "$log_file" 2>/dev/null || echo "unknown")
            log_diagnostic "  $log_file: EXISTS (${size} bytes)"
        else
            log_diagnostic "  $log_file: MISSING"
        fi
    done
}

# Supervisor diagnostics
collect_supervisor_info() {
    print_header "SUPERVISOR DIAGNOSTICS"
    
    if command -v supervisorctl >/dev/null 2>&1; then
        log_diagnostic "Supervisor status:"
        supervisorctl status 2>/dev/null | while read -r line; do
            log_diagnostic "  $line"
        done
        
        log_diagnostic "Supervisor configuration:"
        log_diagnostic "  Config file: $(supervisorctl status 2>/dev/null | head -1 | grep -o '/[^[:space:]]*supervisord.conf' || echo 'Not found')"
    else
        log_diagnostic "supervisorctl not available"
    fi
}

# Recent log analysis
analyze_recent_logs() {
    print_header "RECENT LOG ANALYSIS"
    
    log_diagnostic "Recent supervisor log entries (last 20 lines):"
    if [ -f "/var/log/supervisor/supervisord.log" ]; then
        tail -20 "/var/log/supervisor/supervisord.log" 2>/dev/null | while read -r line; do
            log_diagnostic "  $line"
        done
    else
        log_diagnostic "  Supervisor log not found"
    fi
    
    log_diagnostic "Recent audio-related errors:"
    local audio_logs=("/var/log/supervisor/pipewire.log" "/var/log/supervisor/wireplumber.log" "/var/log/supervisor/audio-validation.log")
    for log_file in "${audio_logs[@]}"; do
        if [ -f "$log_file" ]; then
            log_diagnostic "  From $(basename "$log_file"):"
            tail -10 "$log_file" 2>/dev/null | grep -i "error\|fail\|exit" | while read -r line; do
                log_diagnostic "    $line"
            done
        fi
    done
}

# Recovery status
collect_recovery_info() {
    print_header "RECOVERY SYSTEM STATUS"
    
    if [ -f "/usr/local/bin/service-recovery-manager.sh" ]; then
        log_diagnostic "Service Recovery Manager: AVAILABLE"
        if [ -f "/tmp/service-recovery/failure-counts" ]; then
            log_diagnostic "Current failure counts:"
            while IFS=: read -r service count; do
                log_diagnostic "  $service: $count failures"
            done < "/tmp/service-recovery/failure-counts"
        else
            log_diagnostic "No failure counts recorded"
        fi
    else
        log_diagnostic "Service Recovery Manager: NOT AVAILABLE"
    fi
    
    if [ -f "/usr/local/bin/pipewire-recovery.sh" ]; then
        log_diagnostic "PipeWire Recovery Script: AVAILABLE"
    else
        log_diagnostic "PipeWire Recovery Script: NOT AVAILABLE"
    fi
}

# Generate recommendations
generate_recommendations() {
    print_header "RECOMMENDATIONS"
    
    local recommendations=()
    
    # Check for common issues
    if ! pgrep -f supervisord >/dev/null; then
        recommendations+=("🚨 CRITICAL: Supervisor is not running - container may not have started properly")
    fi
    
    if ! pgrep -f "pipewire" >/dev/null; then
        recommendations+=("⚠️  PipeWire is not running - audio functionality will be unavailable")
    fi
    
    if ! pgrep -f "wireplumber" >/dev/null; then
        recommendations+=("⚠️  WirePlumber is not running - audio device management will not work")
    fi
    
    if ! pgrep -f "Xvfb.*:1" >/dev/null; then
        recommendations+=("🚨 CRITICAL: Xvfb is not running - no display server available")
    fi
    
    if ! pgrep -f "websockify.*80.*:5901" >/dev/null; then
        recommendations+=("⚠️  noVNC is not running - web interface will be unavailable")
    fi
    
    if [ ! -d "/run/user/$DEV_UID" ]; then
        recommendations+=("⚠️  User runtime directory missing - create /run/user/$DEV_UID")
    fi
    
    # Output recommendations
    if [ ${#recommendations[@]} -eq 0 ]; then
        log_diagnostic "✅ No critical issues detected"
    else
        for rec in "${recommendations[@]}"; do
            log_diagnostic "$rec"
        done
    fi
    
    log_diagnostic ""
    log_diagnostic "General troubleshooting steps:"
    log_diagnostic "1. Check supervisor status: supervisorctl status"
    log_diagnostic "2. Restart failed services: supervisorctl restart <service>"
    log_diagnostic "3. Check service logs in /var/log/supervisor/"
    log_diagnostic "4. Run audio recovery: /usr/local/bin/pipewire-recovery.sh recover"
    log_diagnostic "5. Check system resources: free -h && df -h"
}

# Main execution
main() {
    local mode="${1:-full}"
    
    blue "🔍 WebTop System Diagnostics"
    blue "Diagnostic log: $DIAGNOSTIC_LOG"
    echo ""
    
    case "$mode" in
        "quick")
            collect_system_info
            collect_process_info
            collect_network_info
            generate_recommendations
            ;;
        "audio")
            collect_system_info
            collect_user_info
            collect_process_info
            collect_audio_info
            collect_recovery_info
            generate_recommendations
            ;;
        "full"|*)
            collect_system_info
            collect_user_info
            collect_process_info
            collect_network_info
            collect_audio_info
            collect_filesystem_info
            collect_supervisor_info
            analyze_recent_logs
            collect_recovery_info
            generate_recommendations
            ;;
    esac
    
    echo ""
    green "✅ Diagnostics complete!"
    blue "Full diagnostic log saved to: $DIAGNOSTIC_LOG"
    echo ""
    yellow "To share diagnostics, run: cat $DIAGNOSTIC_LOG"
}

main "$@"