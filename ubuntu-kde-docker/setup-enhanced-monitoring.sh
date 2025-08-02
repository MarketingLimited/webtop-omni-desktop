#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📊 Setting up enhanced container monitoring..."

# Create monitoring directories
mkdir -p /var/log/container-monitoring
mkdir -p "${DEV_HOME}/.local/bin/monitoring"

# Install comprehensive health check script
install -m 0755 "${SCRIPT_DIR}/enhanced-health-check.sh" /usr/local/bin/enhanced-health-check.sh

# Create performance monitoring script
cat > "${DEV_HOME}/.local/bin/monitoring/performance-monitor.sh" <<'EOF'
#!/bin/bash

MONITOR_INTERVAL=30
LOG_FILE="/var/log/container-monitoring/performance.log"

echo "🎯 Starting performance monitoring (interval: ${MONITOR_INTERVAL}s)..."

while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # System resources
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    mem_info=$(free | grep Mem)
    mem_used=$(echo "$mem_info" | awk '{printf "%.1f", $3/$2 * 100.0}')
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    load_avg=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | xargs)

    # Network stats
    net_stats=$(grep eth0 /proc/net/dev | head -1 | awk '{print $2,$10}' || echo "0 0")
    rx_bytes=$(echo "$net_stats" | awk '{print $1}')
    tx_bytes=$(echo "$net_stats" | awk '{print $2}')

    # Log performance data
    echo "$timestamp|CPU:$cpu_usage|MEM:$mem_used%|DISK:$disk_usage%|LOAD:$load_avg|NET_RX:$rx_bytes|NET_TX:$tx_bytes" >> "$LOG_FILE"

    sleep "$MONITOR_INTERVAL"
done
EOF

chmod +x "${DEV_HOME}/.local/bin/monitoring/performance-monitor.sh"

# Create monitoring dashboard script
cat > "${DEV_HOME}/.local/bin/monitoring/dashboard.sh" <<'EOF'
#!/bin/bash

clear
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                         Container Monitoring Dashboard                       ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# System overview
echo "🖥️  SYSTEM OVERVIEW"
echo "   Uptime: $(uptime -p)"
echo "   Load:   $(uptime | awk -F'load average:' '{ print $2 }')"
echo ""

# Resource usage
echo "💾 RESOURCE USAGE"
free -h | grep -E '(Mem|Swap)' | while read -r line; do
    echo "   $line"
done
echo "   Disk:   $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')"
echo ""

# Services status
echo "🔧 SERVICES STATUS"
services=("dbus:D-Bus" "kasmvncserver:VNC Server" "plasma:KDE Plasma")
for service_info in "${services[@]}"; do
    service=${service_info%%:*}
    name=${service_info##*:}
    if pgrep -f "$service" >/dev/null; then
        echo "   ✅ $name"
    else
        echo "   ❌ $name"
    fi
done
echo ""

# Network ports
echo "🌐 NETWORK PORTS"
(netstat -tuln 2>/dev/null || ss -tuln 2>/dev/null) | grep LISTEN | grep -E ":(80|22|7681|4713|5555)" | while read -r line; do
    port=$(echo "$line" | awk '{print $4}' | awk -F: '{print $NF}')
    case $port in
        80) echo "   ✅ HTTP/KasmVNC (80)" ;;
        22) echo "   ✅ SSH (22)" ;;
        7681) echo "   ✅ TTYD Terminal (7681)" ;;
        4713) echo "   ✅ PulseAudio (4713)" ;;
        5555) echo "   ✅ ADB Android (5555)" ;;
    esac
done
echo ""

# Wine status
echo "🍷 WINE STATUS"
if [ -d "/home/devuser/.wine" ]; then
    sudo -u devuser bash -c 'export WINEPREFIX="/home/devuser/.wine"; export DISPLAY=:1; WINEDEBUG=-all wine --version 2>/dev/null' \
        && echo "   ✅ Wine functional" || echo "   ⚠️  Wine degraded"
else
    echo "   ❌ Wine not configured"
fi
echo ""

# Android status
echo "🤖 ANDROID STATUS"
if command -v qemu-system-x86_64 >/dev/null; then
    echo "   ✅ QEMU available"
    [ -c /dev/kvm ] && echo "   ✅ KVM acceleration" || echo "   ⚠️  Software emulation only"
else
    echo "   ❌ Android emulator not available"
fi

echo ""
echo "📊 Press Ctrl+C to exit | Refresh: watch -n 5 ~/.local/bin/monitoring/dashboard.sh"
EOF

chmod +x "${DEV_HOME}/.local/bin/monitoring/dashboard.sh"

# Create automated problem resolution script
cat > /usr/local/bin/auto-repair.sh <<'EOF'
#!/bin/bash
set -e

echo "🔧 Starting automated container repair..."

# Restart failed services
restart_service() {
    local service_name=$1
    local start_command=$2

    if ! pgrep -f "$service_name" >/dev/null; then
        echo "🔄 Restarting $service_name..."
        eval "$start_command" &
        sleep 2
    fi
}

# Repair D-Bus
if ! /usr/local/bin/check-dbus >/dev/null 2>&1; then
    echo "🔧 Repairing D-Bus..."
    /usr/local/bin/start-dbus
fi

# Restart core services
restart_service "Xvfb" "Xvfb :1 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset"
restart_service "kasmvncserver" "kasmvncserver :1"

# Clean temporary files if disk usage is high
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 85 ]; then
    echo "🧹 Cleaning temporary files..."
    find /tmp -type f -atime +1 -delete 2>/dev/null || true
    find /var/log -name "*.log" -size +100M -exec truncate -s 50M {} \; 2>/dev/null || true
fi

echo "✅ Automated repair completed"
EOF

chmod +x /usr/local/bin/auto-repair.sh

# Create monitoring cron job
cat > /etc/cron.d/container-monitoring <<'EOF'
# Container monitoring cron jobs
*/5 * * * * root /usr/local/bin/enhanced-health-check.sh >> /var/log/container-monitoring/health.log 2>&1
*/15 * * * * root /usr/local/bin/auto-repair.sh >> /var/log/container-monitoring/repair.log 2>&1
0 */6 * * * root find /var/log/container-monitoring -name "*.log" -size +100M -exec truncate -s 50M {} \;
EOF

# Set ownership and permissions
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}/.local/bin/monitoring"
chmod +x "${DEV_HOME}/.local/bin/monitoring/"*.sh

# Initialize monitoring log directory
touch /var/log/container-monitoring/health.log
touch /var/log/container-monitoring/repair.log
touch /var/log/container-monitoring/performance.log
touch /var/log/container-monitoring/metrics.csv

echo "✅ Enhanced monitoring setup complete"
echo "📊 Available monitoring tools:"
echo "   - Health check: /usr/local/bin/enhanced-health-check.sh"
echo "   - Dashboard: ~/.local/bin/monitoring/dashboard.sh"
echo "   - Performance monitor: ~/.local/bin/monitoring/performance-monitor.sh"
echo "   - Auto repair: /usr/local/bin/auto-repair.sh"

