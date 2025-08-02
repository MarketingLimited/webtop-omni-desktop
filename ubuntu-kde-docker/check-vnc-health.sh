#!/bin/bash
set -e

echo "🔧 Checking VNC server health..."

# Check if VNC server process is running
VNC_PID=$(pgrep -f "kasmvncserver\|vncserver\|tigervncserver" || echo "")

if [ -n "$VNC_PID" ]; then
    echo "✅ VNC server process running with PID: $VNC_PID"
else
    echo "❌ VNC server process not running"
    exit 1
fi

# Check if VNC display is available
if [ -S "/tmp/.X11-unix/X1" ]; then
    echo "✅ VNC display :1 socket exists"
else
    echo "⚠️  VNC display :1 socket not found"
fi

# Check if VNC ports are listening
VNC_HTTP_PORT="${KASMVNC_PORT:-80}"
VNC_VNC_PORT="${KASMVNC_VNC_PORT:-5901}"

if netstat -ln | grep -q ":${VNC_HTTP_PORT}"; then
    echo "✅ VNC HTTP port $VNC_HTTP_PORT is listening"
else
    echo "⚠️  VNC HTTP port $VNC_HTTP_PORT not listening"
fi

if netstat -ln | grep -q ":${VNC_VNC_PORT}"; then
    echo "✅ VNC port $VNC_VNC_PORT is listening"
else
    echo "⚠️  VNC port $VNC_VNC_PORT not listening"
fi

echo "✅ VNC health check completed"
exit 0