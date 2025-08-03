#!/bin/bash
set -e

: "${XSTARTUP_SRC:=/usr/local/share/xstartup}"
: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"

# Capture all output for troubleshooting while still emitting to the
# supervisord log. This helps diagnose early startup failures.
LOG_FILE="/var/log/kasmvnc.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🚀 Starting robust VNC server..."

# Ensure X11 socket directory exists and is writable
if ! install -m 1777 -d /tmp/.X11-unix 2>/dev/null; then
    echo "⚠️  Unable to prepare /tmp/.X11-unix; X11 applications may fail" >&2
fi

# Define possible VNC binary locations
VNC_BINARIES=(
    "/usr/bin/kasmvncserver"
    "/usr/local/bin/kasmvncserver"
    "/opt/kasmvnc/bin/kasmvncserver"
    "/usr/bin/vncserver"
    "/usr/bin/tigervncserver"
)

# Function to find working VNC binary
find_vnc_binary() {
    for binary in "${VNC_BINARIES[@]}"; do
        if [ -x "$binary" ]; then
            echo "✅ Found VNC binary: $binary"
            echo "$binary"
            return 0
        fi
    done
    echo "❌ No VNC binary found in expected locations"
    echo "Available binaries:"
    find /usr -name "*vnc*" -type f -executable 2>/dev/null || echo "No VNC binaries found"
    return 1
}

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

# 2. Find VNC binary
VNC_BINARY=$(find_vnc_binary || true)

# If no binary found, try to install KasmVNC on the fly
if [ -z "$VNC_BINARY" ]; then
    echo "⚠️  No VNC server binary found. Attempting installation..."
    if command -v sudo >/dev/null 2>&1; then
        INSTALL_CMD="sudo /usr/local/bin/setup-kasmvnc.sh"
    else
        INSTALL_CMD="/usr/local/bin/setup-kasmvnc.sh"
    fi

    if $INSTALL_CMD >/var/log/kasmvnc-install.log 2>&1; then
        VNC_BINARY=$(find_vnc_binary || true)
    else
        echo "❌ KasmVNC installation failed. Check /var/log/kasmvnc-install.log for details."
    fi
fi

if [ -z "$VNC_BINARY" ]; then
    echo "❌ No VNC server binary found after installation attempt."
    exit 127
fi

HOME_DIR="${HOME:-/root}"
XAUTH_FILE="$HOME_DIR/.Xauthority"
# 3. Ensure .Xauthority file exists
if [ ! -f "$XAUTH_FILE" ]; then
    echo "🔧 Creating .Xauthority file..."
    touch "$XAUTH_FILE"
    chmod 600 "$XAUTH_FILE"
fi

# 4. Set up X11 environment
export DISPLAY=:1
export XAUTHORITY="$XAUTH_FILE"

# 5. Create VNC configuration if needed
mkdir -p "$HOME_DIR/.vnc"
if [ ! -f "$HOME_DIR/.vnc/xstartup" ]; then
    echo "🔧 Creating VNC xstartup script..."
    if [ -f "$XSTARTUP_SRC" ]; then
        install -m 755 "$XSTARTUP_SRC" "$HOME_DIR/.vnc/xstartup"
    else
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
fi

# 6. Start the VNC server
echo "🚀 Starting KasmVNC server with binary: $VNC_BINARY"

# Pre-configure VNC authentication if needed
if [[ "$VNC_BINARY" == *kasmvncserver* ]]; then
    echo "🔧 Configuring KasmVNC authentication..."

    # Ensure password file exists
    if [ ! -f "$HOME_DIR/.kasmvnc/passwd" ]; then
        mkdir -p "$HOME_DIR/.kasmvnc"
        echo "kasmvnc" | /usr/bin/kasmvncpasswd -f > "$HOME_DIR/.kasmvnc/passwd" 2>/dev/null || true
    fi

    # Create user.conf to avoid interactive prompts
    cat > "$HOME_DIR/.kasmvnc/user.conf" <<EOF
user=$USER:$2b$12$1234567890123456789012$1234567890123456789012345678901234567890:ow:$USER
EOF
fi

# Different startup commands based on VNC server type
case "$VNC_BINARY" in
    *kasmvncserver*)
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
        ;;
    *vncserver*|*tigervncserver*)
        exec "$VNC_BINARY" :1 -geometry 1920x1080 -depth 24 -localhost no
        ;;
    *)
        echo "⚠️  Unknown VNC server type, using basic startup..."
        exec "$VNC_BINARY" :1
        ;;
esac
