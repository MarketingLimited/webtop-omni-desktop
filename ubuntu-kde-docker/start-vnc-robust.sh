#!/bin/bash
set -e

# Capture all output for troubleshooting while still emitting to the
# supervisord log. This helps diagnose early startup failures.
# If the user's home directory is not writable (e.g. due to leftover
# root-owned files), fall back to using /tmp so the script does not
# terminate before starting the VNC server.
LOG_DIR="${HOME:-/tmp}"
if ! mkdir -p "$LOG_DIR" 2>/dev/null; then
    LOG_DIR="/tmp"
    mkdir -p "$LOG_DIR"
fi
LOG_FILE="$LOG_DIR/kasmvnc.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🚀 Starting KasmVNC server..."

# Define the VNC binary path directly
VNC_BINARY="/usr/bin/kasmvncserver"

if [ ! -x "$VNC_BINARY" ]; then
    echo "❌ KasmVNC binary not found at $VNC_BINARY! Skipping start."
    exit 0
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
# 2. Ensure .Xauthority file exists. If the home directory is not writable
# fall back to using a temporary directory so the VNC server can still start
# instead of exiting immediately.
if [ ! -f "$XAUTH_FILE" ]; then
    echo "🔧 Creating .Xauthority file..."
    if ! touch "$XAUTH_FILE" 2>/dev/null; then
        echo "⚠️ Cannot write to $HOME_DIR, falling back to /tmp"
        HOME_DIR="/tmp/kasmvnc"
        mkdir -p "$HOME_DIR"
        XAUTH_FILE="$HOME_DIR/.Xauthority"
        touch "$XAUTH_FILE" || { echo "❌ Failed to create fallback .Xauthority"; exit 1; }
    fi
    chmod 600 "$XAUTH_FILE" 2>/dev/null || true
    export HOME="$HOME_DIR"
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

# Attempt to enable GPU acceleration when a DRI device is available.
# If KasmVNC with GPU acceleration fails, it automatically falls back to
# software rendering. This provides a more robust startup sequence.
if [ -e /dev/dri/renderD128 ]; then
    echo "🔧 DRI device found, attempting to start with GPU acceleration"
    "$VNC_BINARY" :1 \
        -geometry 1920x1080 \
        -depth 24 \
        -interface 0.0.0.0 \
        -httpPort "${KASMVNC_PORT:-80}" \
        -vncPort "${KASMVNC_VNC_PORT:-5901}" \
        -SecurityTypes None \
        -driNode /dev/dri/renderD128 &
    VNC_PID=$!
    sleep 3
    if ! kill -0 "$VNC_PID" >/dev/null 2>&1; then
        echo "⚠️ KasmVNC with GPU acceleration failed. Falling back."
    else
        echo "✅ KasmVNC with GPU acceleration started. Monitoring process."
        wait "$VNC_PID"
        exit $?
    fi
fi

# Fallback to software rendering
echo "🚀 Starting KasmVNC server without GPU acceleration"
exec "$VNC_BINARY" :1 \
    -geometry 1920x1080 \
    -depth 24 \
    -interface 0.0.0.0 \
    -httpPort "${KASMVNC_PORT:-80}" \
    -vncPort "${KASMVNC_VNC_PORT:-5901}" \
    -SecurityTypes None
