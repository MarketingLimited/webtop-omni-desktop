#!/bin/bash
set -e

echo "🩺 Ubuntu KDE Marketing Agency WebTop Health Check"

# Use enhanced health check if available
if [ -f "/usr/local/bin/enhanced-health-check.sh" ]; then
    echo "🔍 Running enhanced health check..."
    /usr/local/bin/enhanced-health-check.sh
    exit $?
fi

# Fallback to basic health check
echo "🔍 Running basic health check..."

# Initialize counters
CRITICAL_ISSUES=0
WARNING_ISSUES=0

# Function to log issues
log_critical() {
    echo "❌ CRITICAL: $1"
    ((CRITICAL_ISSUES++))
}

log_warning() {
    echo "⚠️  WARNING: $1"
    ((WARNING_ISSUES++))
}

log_success() {
    echo "✅ $1"
}

# Check essential services
echo ""
echo "📊 Checking Core Services..."
ESSENTIAL_SERVICES=(
    "supervisord"
    "kasmvncserver"
)

for service in "${ESSENTIAL_SERVICES[@]}"; do
    if pgrep -f "$service" > /dev/null; then
        log_success "$service is running"
    else
        log_critical "$service is not running"
    fi
done

# Check optional but important services
echo ""
echo "🔧 Checking Optional Services..."
OPTIONAL_SERVICES=(
    "pulseaudio"
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

# Check essential ports
echo ""
echo "🌐 Checking Network Ports..."
ESSENTIAL_PORTS=(
    "80:KasmVNC"
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
    if netstat -tln 2>/dev/null | grep -q ":$port "; then
        log_success "Port $port ($service) is listening"
    else
        log_critical "Port $port ($service) is not listening"
    fi
done

for port_info in "${OPTIONAL_PORTS[@]}"; do
    port=${port_info%%:*}
    service=${port_info##*:}
    if netstat -tln 2>/dev/null | grep -q ":$port "; then
        log_success "Port $port ($service) is listening"
    else
        log_warning "Port $port ($service) is not listening"
    fi
done

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
else
    echo "😐 ISSUES: $CRITICAL_ISSUES critical issues, $WARNING_ISSUES warnings"
    exit 1
fi