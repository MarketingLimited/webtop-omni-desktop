#!/bin/bash
set -e

echo "🔧 Checking VNC server health..."

# Detect running VNC server process
VNC_SERVERS=("kasmvncserver" "vncserver" "tigervncserver")
VNC_PID=""
for server in "${VNC_SERVERS[@]}"; do
    VNC_PID=$(pgrep -f "$server" || true)
    if [ -n "$VNC_PID" ]; then
        echo "✅ VNC server process ($server) running with PID: $VNC_PID"
        break
    fi
done

if [ -z "$VNC_PID" ]; then
    echo "❌ VNC server process not running"
    exit 1
fi

# Determine display socket
VNC_DISPLAY="${DISPLAY:-:1}"
DISPLAY_NUM="${VNC_DISPLAY#:}"
DISPLAY_SOCKET="/tmp/.X11-unix/X${DISPLAY_NUM}"

if [ -S "$DISPLAY_SOCKET" ]; then
    echo "✅ VNC display ${VNC_DISPLAY} socket exists"
else
    echo "⚠️  VNC display ${VNC_DISPLAY} socket not found"
fi

# Helper to check if a port is listening using ss or netstat
check_port() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -ln 2>/dev/null | grep -q ":$port"
    elif command -v netstat >/dev/null 2>&1; then
        netstat -ln 2>/dev/null | grep -q ":$port"
    else
        return 1
    fi
}

VNC_HTTP_PORT="${KASMVNC_PORT:-80}"
VNC_VNC_PORT="${KASMVNC_VNC_PORT:-5901}"

for port_info in "$VNC_HTTP_PORT:HTTP" "$VNC_VNC_PORT:VNC"; do
    port="${port_info%%:*}"
    name="${port_info##*:}"
    if check_port "$port"; then
        echo "✅ VNC ${name} port $port is listening"
    else
        echo "⚠️  VNC ${name} port $port not listening"
    fi
done

echo "✅ VNC health check completed"
exit 0

