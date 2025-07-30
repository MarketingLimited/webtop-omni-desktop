#!/bin/bash
set -euo pipefail

echo "🩺 Ubuntu KDE Marketing Agency WebTop Health Check"

# Check if services are running
SERVICES=(
    "supervisord"
    "pulseaudio"
    "Xvnc"
    "xpra"
    "sshd"
)

for service in "${SERVICES[@]}"; do
    if pgrep -f "$service" > /dev/null; then
        echo "✅ $service is running"
    else
        echo "❌ $service is not running"
        exit 1
    fi
done

# Check if ports are listening
PORTS=(
    "22"    # SSH
    "80"    # noVNC
    "5901"  # VNC
    "7681"  # ttyd
    "14500" # Xpra
    "4713"  # PulseAudio
)

for port in "${PORTS[@]}"; do
    if netstat -tln | grep -q ":$port "; then
        echo "✅ Port $port is listening"
    else
        echo "⚠️  Port $port is not listening"
    fi
done

# Check audio system
if pulseaudio --check -v 2>/dev/null; then
    echo "✅ PulseAudio is running"
    
    # Check for virtual sinks
    if pactl list short sinks | grep -q "virtual_speaker"; then
        echo "✅ Virtual audio sink is available"
    else
        echo "⚠️  Virtual audio sink not found"
    fi
else
    echo "❌ PulseAudio is not running properly"
fi

# Check display
if [ -n "${DISPLAY:-}" ]; then
    echo "✅ DISPLAY environment variable is set: $DISPLAY"
    
    if xdpyinfo > /dev/null 2>&1; then
        echo "✅ X11 display is accessible"
    else
        echo "⚠️  X11 display is not accessible"
    fi
else
    echo "⚠️  DISPLAY environment variable is not set"
fi

# Check for marketing applications
MARKETING_APPS=(
    "google-chrome"
    "code"
    "gimp"
    "inkscape"
    "krita"
)

for app in "${MARKETING_APPS[@]}"; do
    if command -v "$app" > /dev/null; then
        echo "✅ $app is installed"
    else
        echo "⚠️  $app is not installed"
    fi
done

# Check flatpak apps
if command -v flatpak > /dev/null; then
    echo "✅ Flatpak is available"
    
    FLATPAK_COUNT=$(flatpak list --app 2>/dev/null | wc -l)
    echo "📦 $FLATPAK_COUNT Flatpak applications installed"
else
    echo "⚠️  Flatpak is not available"
fi

# System resources
echo "💾 Memory usage: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "💿 Disk usage: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
echo "🔢 Load average: $(uptime | awk -F'load average:' '{print $2}')"

echo "🎯 Health check completed!"