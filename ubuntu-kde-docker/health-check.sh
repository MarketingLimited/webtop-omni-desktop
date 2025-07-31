#!/bin/bash
set -euo pipefail

echo "🩺 Ubuntu KDE Marketing Agency WebTop Health Check"

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
    "Xvnc"
    "noVNC"
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
    "80:noVNC"
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