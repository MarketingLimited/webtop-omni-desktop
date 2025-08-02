#!/bin/bash
set -e

echo "🚀 Starting robust VNC server..."

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
    if /usr/local/bin/setup-kasmvnc.sh >/var/log/kasmvnc-install.log 2>&1; then
        VNC_BINARY=$(find_vnc_binary || true)
    else
        echo "❌ KasmVNC installation failed. Check /var/log/kasmvnc-install.log for details."
    fi
fi

if [ -z "$VNC_BINARY" ]; then
    echo "❌ No VNC server binary found after installation attempt."
    exit 127
fi

# 3. Ensure .Xauthority file exists
if [ ! -f /root/.Xauthority ]; then
    echo "🔧 Creating .Xauthority file..."
    touch /root/.Xauthority
    chmod 600 /root/.Xauthority
fi

# 4. Set up X11 environment
export DISPLAY=:1
export XAUTHORITY=/root/.Xauthority

# 5. Create VNC configuration if needed
mkdir -p /root/.vnc
if [ ! -f /root/.vnc/xstartup ]; then
    echo "🔧 Creating VNC xstartup script..."
    cat > /root/.vnc/xstartup << 'EOF'
#!/bin/sh
export XKL_XMODMAP_DISABLE=1
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DISPLAY=:1
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec dbus-launch --exit-with-session /usr/bin/startplasma-x11
EOF
    chmod +x /root/.vnc/xstartup
fi

# 6. Start the VNC server
echo "🚀 Starting KasmVNC server with binary: $VNC_BINARY"

# Pre-configure VNC authentication if needed
if [[ "$VNC_BINARY" == *kasmvncserver* ]]; then
    echo "🔧 Configuring KasmVNC authentication..."
    
    # Ensure password file exists
    if [ ! -f /root/.kasmvnc/passwd ]; then
        mkdir -p /root/.kasmvnc
        echo "kasmvnc" | /usr/bin/kasmvncpasswd -f > /root/.kasmvnc/passwd 2>/dev/null || true
    fi
    
    # Create user.conf to avoid interactive prompts
    cat > /root/.kasmvnc/user.conf << 'EOF'
user=root:$2b$12$1234567890123456789012$1234567890123456789012345678901234567890:ow:root
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
