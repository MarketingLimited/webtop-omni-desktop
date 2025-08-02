#!/bin/bash
set -euo pipefail

echo "🩺 Enhanced Ubuntu KDE Marketing Agency WebTop Health Check"

# Initialize counters
CRITICAL_ISSUES=0
WARNING_ISSUES=0

# Function to log issues
log_critical() {
    echo "❌ CRITICAL: $1"
    ((CRITICAL_ISSUES++)) || true
}

log_warning() {
    echo "⚠️  WARNING: $1"
    ((WARNING_ISSUES++)) || true
}

log_success() {
    echo "✅ $1"
}

log_info() {
    echo "ℹ️  $1"
}

# Determine if a network port is listening using ss or netstat
port_listening() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -tln | grep -q ":$port "
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tln 2>/dev/null | grep -q ":$port "
    else
        return 1
    fi
}

# Check D-Bus status
echo ""
echo "🔧 Checking D-Bus System..."
if [ -S /run/dbus/system_bus_socket ]; then
    log_success "D-Bus system socket exists"
    if pgrep -f "dbus-daemon.*system" > /dev/null; then
        log_success "D-Bus system daemon is running"
    else
        log_warning "D-Bus system daemon not running"
    fi
else
    log_critical "D-Bus system socket missing"
fi

# Check X11 environment
echo ""
echo "🖥️  Checking X11 Environment..."
if [ -S "/tmp/.X11-unix/X1" ]; then
    log_success "X11 display :1 socket exists"
else
    log_warning "X11 display :1 socket not found"
fi

if [ -f "/root/.Xauthority" ]; then
    log_success "X11 authority file exists"
else
    log_warning "X11 authority file missing"
fi

# Check VNC server specifically
echo ""
echo "📺 Checking VNC Server..."
if [ -f "/usr/local/bin/check-vnc-health.sh" ]; then
    if /usr/local/bin/check-vnc-health.sh; then
        log_success "VNC health check passed"
    else
        log_critical "VNC health check failed"
    fi
else
    log_warning "VNC health check script not found"
fi

# Check audio system
echo ""
echo "🔊 Checking Audio System..."
if pgrep -f "pulseaudio" > /dev/null; then
    log_success "PulseAudio is running"
    # Check if audio devices are available
    if command -v pactl >/dev/null 2>&1; then
        audio_info=$(pactl info 2>/dev/null || echo "")
        if [ -n "$audio_info" ]; then
            log_success "PulseAudio server accessible"
        else
            log_warning "PulseAudio server not accessible"
        fi
    fi
else
    log_warning "PulseAudio is not running"
fi

# Check essential services
echo ""
echo "📊 Checking Core Services..."
ESSENTIAL_SERVICES=(
    "supervisord"
)

VNC_SERVICES=(
    "kasmvncserver"
    "vncserver"
    "tigervncserver"
)

for service in "${ESSENTIAL_SERVICES[@]}"; do
    if pgrep -f "$service" > /dev/null; then
        log_success "$service is running"
    else
        log_critical "$service is not running"
    fi
done

# Check VNC services
vnc_running=false
for vnc_service in "${VNC_SERVICES[@]}"; do
    if pgrep -f "$vnc_service" > /dev/null; then
        log_success "VNC server ($vnc_service) is running"
        vnc_running=true
        break
    fi
done

if [ "$vnc_running" = false ]; then
    log_critical "No VNC server is running"
fi

# Check optional services
echo ""
echo "🔧 Checking Optional Services..."
OPTIONAL_SERVICES=(
    "polkitd"
    "sshd"
    "ttyd"
)

for service in "${OPTIONAL_SERVICES[@]}"; do
    if pgrep -f "$service" > /dev/null; then
        log_success "$service is running"
    else
        log_warning "$service is not running"
    fi
done

# Check network ports
echo ""
echo "🌐 Checking Network Ports..."
ESSENTIAL_PORTS=(
    "80:KasmVNC HTTP"
    "5901:VNC"
)

OPTIONAL_PORTS=(
    "22:SSH"
    "7681:ttyd"
    "4713:PulseAudio"
)

for port_info in "${ESSENTIAL_PORTS[@]}"; do
    port=${port_info%%:*}
    service=${port_info##*:}
    if port_listening "$port"; then
        log_success "Port $port ($service) is listening"
    else
        log_critical "Port $port ($service) is not listening"
    fi
done

for port_info in "${OPTIONAL_PORTS[@]}"; do
    port=${port_info%%:*}
    service=${port_info##*:}
    if port_listening "$port"; then
        log_success "Port $port ($service) is listening"
    else
        log_warning "Port $port ($service) is not listening"
    fi
done

# Check disk space
echo ""
echo "💾 Checking Disk Space..."
disk_usage=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
if [ "$disk_usage" -gt 90 ]; then
    log_warning "Disk space usage > 90% ($disk_usage%)"
else
    log_success "Disk space OK ($disk_usage%)"
fi

# Check memory usage
echo ""
echo "🧠 Checking Memory Usage..."
memory_usage=$(awk '/MemTotal/ {total=$2} /MemAvailable/ {avail=$2} END {printf "%d", (total-avail)*100/total}' /proc/meminfo)
if [ "$memory_usage" -gt 90 ]; then
    log_warning "Memory usage > 90% (${memory_usage}%)"
else
    log_success "Memory usage OK (${memory_usage}%)"
fi

# Check supervisor status
echo ""
echo "👥 Checking Supervisor Status..."
if command -v supervisorctl >/dev/null 2>&1; then
    supervisor_status=$(supervisorctl status 2>/dev/null | grep -v RUNNING | wc -l || true)
    if [ "$supervisor_status" -gt 0 ]; then
        log_warning "$supervisor_status supervisor programs not running"
        log_info "Running: supervisorctl status"
        supervisorctl status 2>/dev/null || log_warning "Cannot connect to supervisor"
    else
        log_success "All supervisor programs running"
    fi
else
    log_warning "supervisorctl not available"
fi

# Final health assessment
echo ""
echo "🏥 HEALTH SUMMARY:"
echo "=================="

if [ "$CRITICAL_ISSUES" -eq 0 ] && [ "$WARNING_ISSUES" -eq 0 ]; then
    echo "🎉 EXCELLENT: All systems operational!"
    exit 0
elif [ "$CRITICAL_ISSUES" -eq 0 ]; then
    echo "😊 GOOD: Core systems working, $WARNING_ISSUES minor issues"
    exit 0
elif [ "$CRITICAL_ISSUES" -le 2 ]; then
    echo "😐 DEGRADED: $CRITICAL_ISSUES critical issues, $WARNING_ISSUES warnings"
    exit 1
else
    echo "🚨 FAILED: $CRITICAL_ISSUES critical issues, $WARNING_ISSUES warnings"
    exit 2
fi
