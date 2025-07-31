#!/bin/bash
# System-wide validation script for Ubuntu KDE Docker container
# Validates all services and components after startup

set -e

DEV_USERNAME="${DEV_USERNAME:-devuser}"
VALIDATION_LOG="/var/log/system-validation.log"
REPORT_FILE="/tmp/system-validation-report.txt"

# Color functions for output
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }

# Logging function
log_validation() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [VALIDATION] $1" | tee -a "$VALIDATION_LOG"
}

# Initialize validation report
init_report() {
    cat > "$REPORT_FILE" << 'EOF'
==================================================
    UBUNTU KDE DOCKER SYSTEM VALIDATION REPORT
==================================================

System Status Overview:
EOF
}

# Add result to report
add_result() {
    local component="$1"
    local status="$2"
    local details="$3"
    
    if [ "$status" = "PASS" ]; then
        echo "✅ $component: PASSED" >> "$REPORT_FILE"
    else
        echo "❌ $component: FAILED" >> "$REPORT_FILE"
    fi
    
    if [ -n "$details" ]; then
        echo "   Details: $details" >> "$REPORT_FILE"
    fi
    echo "" >> "$REPORT_FILE"
}

# Validate audio system
validate_audio() {
    log_validation "Validating audio system..."
    
    # Check if PulseAudio is running
    if ! pgrep -x pulseaudio >/dev/null; then
        add_result "Audio System" "FAIL" "PulseAudio daemon not running"
        return 1
    fi
    
    # Check for virtual audio devices
    local sink_count=$(runuser -l "$DEV_USERNAME" -c 'pactl list sinks short 2>/dev/null | wc -l' || echo "0")
    local source_count=$(runuser -l "$DEV_USERNAME" -c 'pactl list sources short 2>/dev/null | wc -l' || echo "0")
    
    if [ "$sink_count" -gt 0 ] && [ "$source_count" -gt 0 ]; then
        add_result "Audio System" "PASS" "PulseAudio running with $sink_count sinks and $source_count sources"
        return 0
    else
        add_result "Audio System" "FAIL" "No audio devices found (sinks: $sink_count, sources: $source_count)"
        return 1
    fi
}

# Validate Xpra service
validate_xpra() {
    log_validation "Validating Xpra service..."
    
    # Check if Xpra process is running
    if ! pgrep -f "xpra.*start" >/dev/null; then
        add_result "Xpra Service" "FAIL" "Xpra process not running"
        return 1
    fi
    
    # Check if port 14500 is listening
    if ! netstat -ln | grep -q ":14500 "; then
        add_result "Xpra Service" "FAIL" "Port 14500 not listening"
        return 1
    fi
    
    # Test basic connectivity
    if curl -s --connect-timeout 5 http://localhost:14500 >/dev/null 2>&1; then
        add_result "Xpra Service" "PASS" "Running and accessible on port 14500"
        return 0
    else
        add_result "Xpra Service" "PARTIAL" "Process running but HTTP interface not responding"
        return 1
    fi
}

# Validate TTYD web terminal
validate_ttyd() {
    log_validation "Validating TTYD web terminal..."
    
    # Check if TTYD process is running
    if ! pgrep -x ttyd >/dev/null; then
        add_result "TTYD Web Terminal" "FAIL" "TTYD process not running"
        return 1
    fi
    
    # Check if port 7681 is listening
    if ! netstat -ln | grep -q ":7681 "; then
        add_result "TTYD Web Terminal" "FAIL" "Port 7681 not listening"
        return 1
    fi
    
    # Test basic connectivity
    if curl -s --connect-timeout 5 http://localhost:7681 >/dev/null 2>&1; then
        add_result "TTYD Web Terminal" "PASS" "Running and accessible on port 7681"
        return 0
    else
        add_result "TTYD Web Terminal" "PARTIAL" "Process running but web interface not responding"
        return 1
    fi
}

# Validate VNC services
validate_vnc() {
    log_validation "Validating VNC services..."
    
    # Check VNC server (x11vnc)
    if ! pgrep -x x11vnc >/dev/null; then
        add_result "VNC Services" "FAIL" "x11vnc process not running"
        return 1
    fi
    
    # Check noVNC web interface (port 80)
    if ! netstat -ln | grep -q ":80 "; then
        add_result "VNC Services" "FAIL" "noVNC port 80 not listening"
        return 1
    fi
    
    # Test noVNC web interface
    if curl -s --connect-timeout 5 http://localhost:80 >/dev/null 2>&1; then
        add_result "VNC Services" "PASS" "VNC server and noVNC web interface running"
        return 0
    else
        add_result "VNC Services" "PARTIAL" "VNC server running but web interface not responding"
        return 1
    fi
}

# Validate all supervisor services
validate_supervisor_services() {
    log_validation "Validating supervisor services..."
    
    local failed_services=()
    local running_services=0
    local total_services=0
    
    # Get supervisor status
    while IFS= read -r line; do
        if [[ "$line" == *"RUNNING"* ]]; then
            ((running_services++))
        elif [[ "$line" == *"FATAL"* ]] || [[ "$line" == *"BACKOFF"* ]]; then
            local service_name=$(echo "$line" | awk '{print $1}')
            failed_services+=("$service_name")
        fi
        ((total_services++))
    done < <(supervisorctl status | tail -n +2)
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        add_result "Supervisor Services" "PASS" "$running_services/$total_services services running"
        return 0
    else
        local failed_list=$(IFS=', '; echo "${failed_services[*]}")
        add_result "Supervisor Services" "FAIL" "Failed services: $failed_list"
        return 1
    fi
}

# Validate network ports
validate_ports() {
    log_validation "Validating network ports..."
    
    local expected_ports=(80 5901 14500 7681 22)
    local listening_ports=()
    local missing_ports=()
    
    for port in "${expected_ports[@]}"; do
        if netstat -ln | grep -q ":$port "; then
            listening_ports+=("$port")
        else
            missing_ports+=("$port")
        fi
    done
    
    if [ ${#missing_ports[@]} -eq 0 ]; then
        local ports_list=$(IFS=', '; echo "${listening_ports[*]}")
        add_result "Network Ports" "PASS" "All expected ports listening: $ports_list"
        return 0
    else
        local missing_list=$(IFS=', '; echo "${missing_ports[*]}")
        add_result "Network Ports" "FAIL" "Missing ports: $missing_list"
        return 1
    fi
}

# Validate KDE desktop environment
validate_kde() {
    log_validation "Validating KDE desktop environment..."
    
    # Check if KDE processes are running
    if ! pgrep -f "startplasma-x11\|plasmashell\|kwin" >/dev/null; then
        add_result "KDE Desktop" "FAIL" "KDE desktop processes not running"
        return 1
    fi
    
    # Check if X11 display is available
    if ! DISPLAY=:1 xdpyinfo >/dev/null 2>&1; then
        add_result "KDE Desktop" "FAIL" "X11 display :1 not available"
        return 1
    fi
    
    add_result "KDE Desktop" "PASS" "KDE desktop environment running on display :1"
    return 0
}

# Generate final report summary
generate_summary() {
    local total_tests=7
    local passed_tests=0
    
    # Count passed tests from report
    passed_tests=$(grep -c "✅.*PASSED" "$REPORT_FILE" || echo "0")
    
    cat >> "$REPORT_FILE" << EOF

==================================================
                VALIDATION SUMMARY
==================================================

Tests Passed: $passed_tests/$total_tests

EOF

    if [ "$passed_tests" -eq "$total_tests" ]; then
        cat >> "$REPORT_FILE" << EOF
🎉 ALL TESTS PASSED! 

Your Ubuntu KDE Docker container is fully functional:

📱 Access Methods:
  • noVNC Web Desktop: http://localhost:80
  • Xpra Remote Desktop: http://localhost:14500  
  • Web Terminal: http://localhost:7681
  • SSH: ssh devuser@localhost -p 22

🔊 Audio: Virtual audio devices are configured and working
🖥️  Desktop: KDE Plasma desktop environment is running
📡 Services: All supervisor services are stable

EOF
    else
        cat >> "$REPORT_FILE" << EOF
⚠️  SOME TESTS FAILED

Please check the failed components above and review the logs:
  • System validation: /var/log/system-validation.log
  • Supervisor logs: /var/log/supervisor/
  • Service health: /var/log/supervisor/health.log

EOF
    fi

    cat >> "$REPORT_FILE" << EOF
Generated: $(date)
==================================================
EOF
}

# Main validation function
main() {
    log_validation "Starting system validation..."
    
    init_report
    
    local exit_code=0
    
    # Run all validation tests
    validate_supervisor_services || exit_code=1
    validate_kde || exit_code=1
    validate_audio || exit_code=1
    validate_vnc || exit_code=1
    validate_xpra || exit_code=1
    validate_ttyd || exit_code=1
    validate_ports || exit_code=1
    
    # Generate summary
    generate_summary
    
    # Display report
    echo ""
    blue "=== SYSTEM VALIDATION REPORT ==="
    cat "$REPORT_FILE"
    
    log_validation "System validation completed with exit code: $exit_code"
    
    # Copy report to accessible location
    cp "$REPORT_FILE" "/home/$DEV_USERNAME/system-validation-report.txt" 2>/dev/null || true
    
    exit $exit_code
}

# Handle script arguments
case "${1:-}" in
    "audio") validate_audio ;;
    "xpra") validate_xpra ;;
    "ttyd") validate_ttyd ;;
    "vnc") validate_vnc ;;
    "services") validate_supervisor_services ;;
    "ports") validate_ports ;;
    "kde") validate_kde ;;
    *) main "$@" ;;
esac