#!/bin/bash
# System-wide validation script for Ubuntu KDE Docker container
# Validates all services and components after startup

set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
VALIDATION_LOG="/var/log/system-validation.log"
REPORT_FILE="/tmp/system-validation-report.txt"
CACHE_FILE="/tmp/validation-cache.txt"
OPTIMIZED_MODE=false

# Determine available socket listing command
SOCKET_CMD=(ss -ltn)
if ! command -v ss >/dev/null 2>&1; then
    SOCKET_CMD=(netstat -ln)
fi

# Color function for output
blue() { echo -e "\033[34m$1\033[0m"; }

# Logging function with level support
log_validation() {
    local level="${2:-INFO}"
    if [ "$OPTIMIZED_MODE" = "false" ] || [ "$level" = "ERROR" ] || [ "$level" = "WARN" ]; then
        printf '%s [%s] [VALIDATION] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$1" | tee -a "$VALIDATION_LOG" >/dev/null || true
    fi
}

if [ "${HEADLESS_MODE:-false}" = "true" ]; then
    log_validation "Headless mode detected, skipping system validation" "INFO"
    exit 0
fi

# Ensure required utilities exist; if they're missing we log the issue and
# exit successfully. Missing tools shouldn't cause the container to thrash.
REQUIRED_CMDS=(pgrep supervisorctl curl)
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_validation "$cmd command not found, skipping system validation" "WARN"
        exit 0
    fi
done

# Check if validation cache is valid (within last hour)
is_cache_valid() {
    if [ -f "$CACHE_FILE" ]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))
        [ $cache_age -lt 3600 ]  # 1 hour cache validity
    else
        false
    fi
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

    case "$status" in
        PASS)
            echo "✅ $component: PASSED" >> "$REPORT_FILE"
            ;;
        PARTIAL)
            echo "⚠️  $component: PARTIAL" >> "$REPORT_FILE"
            ;;
        *)
            echo "❌ $component: FAILED" >> "$REPORT_FILE"
            ;;
    esac

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
    local sink_count
    sink_count=$(runuser -l "$DEV_USERNAME" -c 'pactl list sinks short 2>/dev/null | wc -l' || echo "0")
    local source_count
    source_count=$(runuser -l "$DEV_USERNAME" -c 'pactl list sources short 2>/dev/null | wc -l' || echo "0")
    
    if [ "$sink_count" -gt 0 ] && [ "$source_count" -gt 0 ]; then
        add_result "Audio System" "PASS" "PulseAudio running with $sink_count sinks and $source_count sources"
        return 0
    else
        add_result "Audio System" "FAIL" "No audio devices found (sinks: $sink_count, sources: $source_count)"
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
    if ! "${SOCKET_CMD[@]}" | grep -q ":7681 "; then
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
    
    # Check VNC server (KasmVNC)
    if ! pgrep -f kasmvncserver >/dev/null; then
        add_result "VNC Services" "FAIL" "KasmVNC process not running"
        return 1
    fi
    
    # Check KasmVNC web interface (port 80)
    if ! "${SOCKET_CMD[@]}" | grep -q ":80 "; then
        add_result "VNC Services" "FAIL" "KasmVNC port 80 not listening"
        return 1
    fi
    
    # Test KasmVNC web interface
    if curl -s --connect-timeout 5 http://localhost:80 >/dev/null 2>&1; then
        add_result "VNC Services" "PASS" "KasmVNC server and web interface running"
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
    local service_name
    local supervisor_output

    if ! supervisor_output=$(supervisorctl status 2>/dev/null); then
        add_result "Supervisor Services" "FAIL" "Unable to retrieve supervisor status"
        return 1
    fi

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" == *"RUNNING"* ]]; then
            ((running_services++))
        elif [[ "$line" == *"FATAL"* ]] || [[ "$line" == *"BACKOFF"* ]]; then
            service_name=$(awk '{print $1}' <<< "$line")
            failed_services+=("$service_name")
        fi
        ((total_services++))
    done <<< "$supervisor_output"
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        add_result "Supervisor Services" "PASS" "$running_services/$total_services services running"
        return 0
    else
        local failed_list
        failed_list=$(IFS=', '; echo "${failed_services[*]}")
        add_result "Supervisor Services" "FAIL" "Failed services: $failed_list"
        return 1
    fi
}

# Validate network ports
validate_ports() {
    log_validation "Validating network ports..."
    
    local expected_ports=(80 5901 7681 22)
    local listening_ports=()
    local missing_ports=()
    local socket_info

    if ! socket_info=$("${SOCKET_CMD[@]}" 2>/dev/null); then
        add_result "Network Ports" "FAIL" "Unable to list network ports"
        return 1
    fi

    for port in "${expected_ports[@]}"; do
        if grep -q ":$port " <<< "$socket_info"; then
            listening_ports+=("$port")
        else
            missing_ports+=("$port")
        fi
    done
    
    if [ ${#missing_ports[@]} -eq 0 ]; then
        local ports_list
        ports_list=$(IFS=', '; echo "${listening_ports[*]}")
        add_result "Network Ports" "PASS" "All expected ports listening: $ports_list"
        return 0
    else
        local missing_list
        missing_list=$(IFS=', '; echo "${missing_ports[*]}")
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
    local total_tests=6
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
  • KasmVNC Web Desktop: http://localhost:80
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

# Quick validation for optimized mode
quick_validation() {
    log_validation "Running quick validation check..." "INFO"
    
    # Quick supervisor check
    if ! supervisorctl status | grep -q "RUNNING"; then
        log_validation "Quick validation failed - supervisor issues detected" "WARN"
        return 1
    fi
    
    # Quick port check
    local critical_ports=(80 5901)
    for port in "${critical_ports[@]}"; do
        if ! "${SOCKET_CMD[@]}" | grep -q ":$port "; then
            log_validation "Quick validation failed - critical port $port not listening" "WARN"
            return 1
        fi
    done
    
    log_validation "Quick validation passed - system appears healthy" "INFO"
    return 0
}

# Main validation function
main() {
    # Check for optimized mode flag
    if [ "$1" = "--optimized" ]; then
        OPTIMIZED_MODE=true
        log_validation "Starting optimized system validation..." "INFO"
        
        # If cache is valid and quick validation passes, exit early
        if is_cache_valid && quick_validation; then
            log_validation "Using cached validation results (system stable)" "INFO"
            exit 0
        fi
    else
        log_validation "Starting full system validation..." "INFO"
    fi
    
    init_report
    
    local exit_code=0
    
    # Run all validation tests
    validate_supervisor_services || exit_code=1
    validate_kde || exit_code=1
    validate_audio || exit_code=1
    validate_vnc || exit_code=1
    validate_ttyd || exit_code=1
    validate_ports || exit_code=1
    
    # Generate summary
    generate_summary
    
    # Cache results if successful
    if [ $exit_code -eq 0 ]; then
        date +%s > "$CACHE_FILE"
    fi
    
    # Display report (only in non-optimized mode or if there are issues)
    if [ "$OPTIMIZED_MODE" = "false" ] || [ $exit_code -ne 0 ]; then
        echo ""
        blue "=== SYSTEM VALIDATION REPORT ==="
        cat "$REPORT_FILE"
    fi
    
    log_validation "System validation completed with exit code: $exit_code" "INFO"

    # Copy report to accessible location
    cp "$REPORT_FILE" "/home/$DEV_USERNAME/system-validation-report.txt" 2>/dev/null || true

    # Always exit successfully to avoid restart loops when optional
    # components fail validation in container environments.
    exit 0
}

# Handle script arguments
case "${1:-}" in
    "audio") validate_audio ;;
    "ttyd") validate_ttyd ;;
    "vnc") validate_vnc ;;
    "services") validate_supervisor_services ;;
    "ports") validate_ports ;;
    "kde") validate_kde ;;
    "quick") quick_validation ;;
    "--optimized") main "$@" ;;
    *) main "$@" ;;
esac
