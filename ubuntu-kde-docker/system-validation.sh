#!/bin/bash
# Enhanced System Validation Script
# Performs comprehensive system health checks for container environment

set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_UID="${DEV_UID:-1000}"

LOG_FILE="/var/log/supervisor/system-validation.log"
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    local message="$1"
    local level="${2:-INFO}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] [VALIDATION] $message" | tee -a "$LOG_FILE"
}

# Validation results tracking
VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0

record_error() {
    local message="$1"
    log_message "$message" "ERROR"
    VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
}

record_warning() {
    local message="$1"
    log_message "$message" "WARN"
    VALIDATION_WARNINGS=$((VALIDATION_WARNINGS + 1))
}

# Check system users
validate_users() {
    log_message "Validating system users..."
    
    # Check messagebus user
    if ! id messagebus >/dev/null 2>&1; then
        record_warning "messagebus user not found"
    else
        log_message "messagebus user: OK"
    fi
    
    # Check development user
    if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
        record_warning "Development user $DEV_USERNAME not found"
    else
        local actual_uid
        actual_uid=$(id -u "$DEV_USERNAME")
        if [ "$actual_uid" != "$DEV_UID" ]; then
            record_warning "Development user UID mismatch: expected $DEV_UID, got $actual_uid"
        else
            log_message "Development user: OK"
        fi
    fi
}

# Check essential directories
validate_directories() {
    log_message "Validating essential directories..."
    
    local critical_dirs=(
        "/run/dbus"
        "/var/log/supervisor"
        "/tmp/.X11-unix"
    )
    
    for dir in "${critical_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            record_error "Critical directory missing: $dir"
        else
            log_message "Directory $dir: OK"
        fi
    done
    
    # Check user runtime directory
    local runtime_dir="/run/user/${DEV_UID}"
    if [ ! -d "$runtime_dir" ]; then
        record_warning "User runtime directory missing: $runtime_dir"
    else
        log_message "User runtime directory: OK"
    fi
}

# Check system services
validate_services() {
    log_message "Validating system services..."
    
    # Check D-Bus
    if [ -S /run/dbus/system_bus_socket ]; then
        if dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetId >/dev/null 2>&1; then
            log_message "D-Bus system service: OK"
        else
            record_error "D-Bus system service not responsive"
        fi
    else
        record_error "D-Bus system socket not found"
    fi
    
    # Check supervisor services
    local expected_services=(
        "dbus"
        "pulseaudio"
        "kasmvnc"
        "sshd"
        "ttyd"
        "servicehealth"
    )
    
    for service in "${expected_services[@]}"; do
        if supervisorctl status "$service" >/dev/null 2>&1; then
            local status
            status=$(supervisorctl status "$service" | awk '{print $2}')
            if [ "$status" = "RUNNING" ]; then
                log_message "Service $service: OK"
            else
                record_warning "Service $service not running: $status"
            fi
        else
            record_warning "Service $service not found in supervisor"
        fi
    done
}

# Check audio system
validate_audio() {
    log_message "Validating audio system..."
    
    if [ "${HEADLESS_MODE:-false}" = "true" ]; then
        log_message "Headless mode - skipping audio validation"
        return 0
    fi
    
    # Check PulseAudio
    if pgrep -x pulseaudio >/dev/null; then
        log_message "PulseAudio daemon: OK"
    else
        record_warning "PulseAudio daemon not running"
    fi
    
    # Check audio devices (if user exists)
    if id "$DEV_USERNAME" >/dev/null 2>&1; then
        local device_count=0
        if device_count=$(su - "$DEV_USERNAME" -c "export XDG_RUNTIME_DIR=/run/user/${DEV_UID}; pactl list short sinks 2>/dev/null | wc -l"); then
            if [ "$device_count" -gt 0 ]; then
                log_message "Audio devices available: $device_count"
            else
                record_warning "No audio devices found"
            fi
        else
            record_warning "Cannot query audio devices"
        fi
    fi
}

# Check network connectivity
validate_network() {
    log_message "Validating network connectivity..."
    
    # Check localhost connectivity
    if nc -z localhost 22 2>/dev/null; then
        log_message "SSH service accessible: OK"
    else
        record_warning "SSH service not accessible on localhost"
    fi
    
    # Check VNC port
    if nc -z localhost 5901 2>/dev/null; then
        log_message "VNC service accessible: OK"
    else
        record_warning "VNC service not accessible on localhost"
    fi
    
    # Check web terminal
    if nc -z localhost 7681 2>/dev/null; then
        log_message "Web terminal accessible: OK"
    else
        record_warning "Web terminal not accessible on localhost"
    fi
}

# Check essential binaries
validate_binaries() {
    log_message "Validating essential binaries..."
    
    local essential_bins=(
        "dbus-daemon"
        "pulseaudio"
        "ssh"
        "supervisorctl"
    )
    
    for bin in "${essential_bins[@]}"; do
        if command -v "$bin" >/dev/null 2>&1; then
            log_message "Binary $bin: OK"
        else
            record_error "Essential binary missing: $bin"
        fi
    done
    
    # Check desktop environment binaries
    local desktop_bins=(
        "startplasma-x11"
        "kwin_x11"
        "plasmashell"
    )
    
    for bin in "${desktop_bins[@]}"; do
        if command -v "$bin" >/dev/null 2>&1; then
            log_message "Desktop binary $bin: OK"
        else
            record_warning "Desktop binary missing: $bin"
        fi
    done
}

# Generate validation report
generate_report() {
    log_message "=== SYSTEM VALIDATION REPORT ==="
    log_message "Errors: $VALIDATION_ERRORS"
    log_message "Warnings: $VALIDATION_WARNINGS"
    
    if [ $VALIDATION_ERRORS -eq 0 ]; then
        if [ $VALIDATION_WARNINGS -eq 0 ]; then
            log_message "System validation: PASSED (no issues)"
            return 0
        else
            log_message "System validation: PASSED (with warnings)"
            return 0
        fi
    else
        log_message "System validation: FAILED ($VALIDATION_ERRORS critical errors)"
        # Don't exit with error code to prevent supervisor restart loops
        return 0
    fi
}

# Main validation execution
main() {
    log_message "Starting comprehensive system validation"
    
    validate_users
    validate_directories
    validate_services
    validate_audio
    validate_network
    validate_binaries
    
    generate_report
}

main "$@"