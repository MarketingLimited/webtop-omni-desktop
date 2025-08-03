#!/bin/bash
set -e

# Capture all output for troubleshooting while still emitting to the
# supervisord log. This helps diagnose early startup failures.
LOG_FILE="/var/log/kasmvnc.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🚀 Starting KasmVNC server..."

# Define the VNC binary path directly
VNC_BINARY="/usr/bin/kasmvncserver"

if [ ! -x "$VNC_BINARY" ]; then
    echo "❌ KasmVNC binary not found at $VNC_BINARY!"
    echo "Please ensure the Docker image was built correctly and the KasmVNC .deb package was installed."
    exit 127
fi

# 1. Wait for the D-Bus socket to be created
echo "🔧 Waiting for D-Bus socket before starting VNC..."
counter=0
while [ ! -S /run/dbus/system_bus_socket ] && [ $counter -lt 30 ]; do
  sleep 1
  counter=$((counter+1))
done

if [ ! -S /run/dbus/system_bus_socket ]; then
  echo "❌ D-Bus socket not available. VNC will not start."
  exit 1
fi
echo "✅ D-Bus is ready."


HOME_DIR="${HOME:-/root}"
XAUTH_FILE="$HOME_DIR/.Xauthority"
# 2. Ensure .Xauthority file exists
if [ ! -f "$XAUTH_FILE" ]; then
    echo "🔧 Creating .Xauthority file..."
    touch "$XAUTH_FILE"
    chmod 600 "$XAUTH_FILE"
fi

# 3. Set up X11 environment
export DISPLAY=:1
export XAUTHORITY="$XAUTH_FILE"

# 4. Create VNC configuration if needed
mkdir -p "$HOME_DIR/.vnc"
if [ ! -f "$HOME_DIR/.vnc/xstartup" ]; then
    echo "🔧 Creating VNC xstartup script..."
    cat > "$HOME_DIR/.vnc/xstartup" <<'EOF'
#!/bin/sh
export XKL_XMODMAP_DISABLE=1
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DISPLAY=${DISPLAY:-:1}
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

if command -v startplasma-x11 >/dev/null 2>&1; then
  dbus-launch --exit-with-session startplasma-x11 || xterm
else
  echo "startplasma-x11 not found, launching xterm" >&2
  xterm
fi
EOF
    chmod 755 "$HOME_DIR/.vnc/xstartup"
fi

# 5. Start the VNC server
echo "🚀 Starting KasmVNC server with binary: $VNC_BINARY"

exec "$VNC_BINARY" :1 \
    -geometry 1920x1080 \
    -depth 24 \
    -interface 0.0.0.0 \
    -httpPort "${KASMVNC_PORT:-80}" \
    -vncPort "${KASMVNC_VNC_PORT:-5901}" \
    -SecurityTypes None \
    -select-de manual \
    -driNode /dev/dri/renderD128 2>/dev/null || \
exec "$VNC_BINARY" :1 \
    -geometry 1920x1080 \
    -depth 24 \
    -interface 0.0.0.0 \
    -httpPort "${KASMVNC_PORT:-80}" \
    -vncPort "${KASMVNC_VNC_PORT:-5901}" \
    -SecurityTypes None
